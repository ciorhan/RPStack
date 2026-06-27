-- Faction treasury operations. Economy owns every balance mutation.

RPSTACK_FACTIONS_TREASURY = {}

local function acquireLock(factionId, cb)
  local deadline = GetGameTimer() + 5000
  CreateThread(function()
    while RPSTACK_FACTIONS_STATE.treasury_locked[factionId] do
      if GetGameTimer() > deadline then
        cb(false)
        return
      end
      Wait(50)
    end
    RPSTACK_FACTIONS_STATE.treasury_locked[factionId] = true
    cb(true)
  end)
end

local function releaseLock(factionId)
  RPSTACK_FACTIONS_STATE.treasury_locked[factionId] = nil
end

local function isPositiveInteger(value)
  return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function validateNote(note)
  return note == nil or (type(note) == "string" and #note <= 128)
end

local function callEconomy(exportName, invoke, onError)
  local ok, err = pcall(invoke, exports["rpstack-economy"])
  if not ok then
    RPSTACK_LOG.error("factions", "economy export failed", {
      export = exportName,
      error = tostring(err),
    })
    onError()
  end
end

function RPSTACK_FACTIONS_TREASURY.getBalance(factionId, cb)
  if type(cb) ~= "function" then return end
  if not isPositiveInteger(factionId) or not RPSTACK_FACTIONS_STATE.factions[factionId] then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end

  callEconomy("getAccountByOwner", function(econ)
    econ['rpstack:economy:getAccountByOwner'](
      econ,
      "faction",
      factionId,
      "treasury",
      function(result)
        if not result or not result.ok or not result.account then
          cb({ ok = false, error = result and result.error or RPSTACK_ERRORS.NOT_FOUND })
          return
        end
        cb({ ok = true, cash = result.account.cash, bank = result.account.bank })
      end
    )
  end, function()
    cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
  end)
end

function RPSTACK_FACTIONS_TREASURY.getLedger(factionId, limit, cb)
  if type(cb) ~= "function" then return end
  if not isPositiveInteger(factionId) or not RPSTACK_FACTIONS_STATE.factions[factionId] then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end

  limit = limit or 50
  if not isPositiveInteger(limit) or limit > 100 then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end

  RPSTACK_FACTIONS_REPO.getTreasuryLedger(factionId, limit, function(entries)
    cb({ ok = true, entries = entries or {} })
  end)
end

local function transfer(
  factionId,
  characterId,
  amount,
  note,
  permission,
  fromType,
  fromId,
  fromAccount,
  toType,
  toId,
  toAccount,
  auditAction,
  cb
)
  if type(cb) ~= "function" then return end
  if not isPositiveInteger(factionId)
    or not isPositiveInteger(characterId)
    or not RPSTACK_FACTIONS_STATE.factions[factionId]
  then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end
  if not RPSTACK_FACTIONS_RANKS.hasPerm(factionId, characterId, permission) then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end
  if not isPositiveInteger(amount) or not validateNote(note) then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end

  local maxAmount = auditAction == FACTION_AUDIT.TREASURY_DEPOSIT
    and RPSTACK_FACTIONS_CONFIG.treasury_max_deposit
    or RPSTACK_FACTIONS_CONFIG.treasury_max_withdraw
  if maxAmount and maxAmount > 0 and amount > maxAmount then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end

  acquireLock(factionId, function(locked)
    if not locked then
      cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
      return
    end

    callEconomy("transferCash", function(econ)
      econ['rpstack:economy:transferCash'](
        econ,
        fromType,
        fromId,
        fromAccount,
        toType,
        toId,
        toAccount,
        amount,
        "faction_treasury:" .. factionId,
        function(result)
          releaseLock(factionId)
          if not result or not result.ok then
            cb({
              ok = false,
              error = result and result.error or RPSTACK_ERRORS.INTERNAL,
            })
            return
          end

          local factionBalance = auditAction == FACTION_AUDIT.TREASURY_DEPOSIT
            and result.destinationCash
            or result.sourceCash

          RPSTACK_FACTIONS_AUDIT.log(factionId, characterId, auditAction, {
            amount = amount,
            note = note or "",
            newBalance = factionBalance,
          })
          TriggerEvent(FACTION_EVENTS.TREASURY_CHANGED, {
            factionId = factionId,
            delta = auditAction == FACTION_AUDIT.TREASURY_DEPOSIT and amount or -amount,
            newBalance = factionBalance,
          })

          cb({ ok = true, newBalance = factionBalance })
        end
      )
    end, function()
      releaseLock(factionId)
      cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
    end)
  end)
end

function RPSTACK_FACTIONS_TREASURY.deposit(factionId, characterId, amount, note, cb)
  transfer(
    factionId,
    characterId,
    amount,
    note,
    FACTION_PERMS.DEPOSIT,
    "character",
    characterId,
    "default",
    "faction",
    factionId,
    "treasury",
    FACTION_AUDIT.TREASURY_DEPOSIT,
    cb
  )
end

function RPSTACK_FACTIONS_TREASURY.withdraw(factionId, characterId, amount, note, cb)
  transfer(
    factionId,
    characterId,
    amount,
    note,
    FACTION_PERMS.WITHDRAW,
    "faction",
    factionId,
    "treasury",
    "character",
    characterId,
    "default",
    FACTION_AUDIT.TREASURY_WITHDRAW,
    cb
  )
end
