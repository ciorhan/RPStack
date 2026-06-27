-- rpstack-factions/server/treasury.lua
-- Faction treasury operations.
-- All money movement goes through rpstack-economy exports.
-- Economy owns rpstack_economy_accounts — we never touch it directly.
--
-- Async pattern: matches rpstack-economy's callback-based exports.
--
-- Per-faction mutex: treasury_locked[factionId] serializes concurrent
-- deposit/withdraw so two simultaneous operations cannot race.

RPSTACK_FACTIONS_TREASURY = {}

-- ── Internal: per-faction lock (spin with timeout) ────────────────────────────

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

-- ── Reads ─────────────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_TREASURY.getBalance(factionId, cb)
  local econ = exports["rpstack-economy"]
  econ['rpstack:economy:getAccountByOwner'](econ, "faction", factionId, "treasury", function(result)
    if not result or not result.ok or not result.account then
      cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
      return
    end
    cb({ ok = true, cash = result.account.cash, bank = result.account.bank })
  end)
end

function RPSTACK_FACTIONS_TREASURY.getLedger(factionId, limit, cb)
  if not RPSTACK_FACTIONS_STATE.factions[factionId] then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end
  local entries = RPSTACK_FACTIONS_REPO.getTreasuryLedger(factionId, limit or 50)
  cb({ ok = true, entries = entries or {} })
end

-- ── Deposit ───────────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_TREASURY.deposit(factionId, characterId, amount, note, cb)
  if not RPSTACK_FACTIONS_STATE.factions[factionId] then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end
  if not RPSTACK_FACTIONS_RANKS.hasPerm(factionId, characterId, FACTION_PERMS.DEPOSIT) then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end
  if type(amount) ~= "number" or amount <= 0 then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end
  local max = RPSTACK_FACTIONS_CONFIG.treasury_max_deposit
  if max and max > 0 and amount > max then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end

  acquireLock(factionId, function(locked)
    if not locked then
      cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
      return
    end

    local econ = exports["rpstack-economy"]

    -- Step 1: deduct from character cash
    econ['rpstack:economy:adjustCashByCharId'](econ, characterId, -amount, "faction_deposit:" .. factionId, function(r1)
      if not r1 or not r1.ok then
        releaseLock(factionId)
        cb({ ok = false, error = r1 and r1.error or RPSTACK_ERRORS.INTERNAL })
        return
      end

      -- Step 2: credit faction treasury
      econ['rpstack:economy:adjustOwnerCash'](econ, "faction", factionId, "treasury", amount, "deposit_from:" .. characterId, function(r2)
        if not r2 or not r2.ok then
          -- Rollback: return cash to character
          econ['rpstack:economy:adjustCashByCharId'](econ, characterId, amount, "faction_deposit_rollback:" .. factionId, function() end)
          releaseLock(factionId)
          cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
          return
        end

        releaseLock(factionId)

        RPSTACK_FACTIONS_AUDIT.log(factionId, characterId, FACTION_AUDIT.TREASURY_DEPOSIT, {
          amount = amount, note = note or "", newBalance = r2.newCash
        })
        TriggerEvent(FACTION_EVENTS.TREASURY_CHANGED, {
          factionId = factionId, delta = amount, newBalance = r2.newCash
        })

        cb({ ok = true, newBalance = r2.newCash })
      end)
    end)
  end)
end

-- ── Withdraw ──────────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_TREASURY.withdraw(factionId, characterId, amount, note, cb)
  if not RPSTACK_FACTIONS_STATE.factions[factionId] then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end
  if not RPSTACK_FACTIONS_RANKS.hasPerm(factionId, characterId, FACTION_PERMS.WITHDRAW) then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end
  if type(amount) ~= "number" or amount <= 0 then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end
  local max = RPSTACK_FACTIONS_CONFIG.treasury_max_withdraw
  if max and max > 0 and amount > max then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end

  acquireLock(factionId, function(locked)
    if not locked then
      cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
      return
    end

    local econ = exports["rpstack-economy"]

    -- Step 1: deduct from treasury
    econ['rpstack:economy:adjustOwnerCash'](econ, "faction", factionId, "treasury", -amount, "withdrawal_by:" .. characterId, function(r1)
      if not r1 or not r1.ok then
        releaseLock(factionId)
        cb({ ok = false, error = r1 and r1.error or RPSTACK_ERRORS.INTERNAL })
        return
      end

      -- Step 2: credit character cash
      econ['rpstack:economy:adjustCashByCharId'](econ, characterId, amount, "faction_withdrawal:" .. factionId, function(r2)
        if not r2 or not r2.ok then
          -- Rollback: return funds to treasury
          econ['rpstack:economy:adjustOwnerCash'](econ, "faction", factionId, "treasury", amount, "withdrawal_rollback", function() end)
          releaseLock(factionId)
          cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
          return
        end

        releaseLock(factionId)

        RPSTACK_FACTIONS_AUDIT.log(factionId, characterId, FACTION_AUDIT.TREASURY_WITHDRAW, {
          amount = amount, note = note or "", newBalance = r1.newCash
        })
        TriggerEvent(FACTION_EVENTS.TREASURY_CHANGED, {
          factionId = factionId, delta = -amount, newBalance = r1.newCash
        })

        cb({ ok = true, newBalance = r1.newCash })
      end)
    end)
  end)
end