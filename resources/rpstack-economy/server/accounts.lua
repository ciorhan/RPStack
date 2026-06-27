-- Generic economy account operations. All persistence stays in economy_repo.lua.

RPSTACK_ECONOMY_ACCOUNTS = {}

local function isPositiveInteger(value)
  return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function isToken(value, maxLength)
  return type(value) == "string"
    and #value > 0
    and #value <= maxLength
    and value:match("^[a-z][a-z0-9_]*$") ~= nil
end

local function isValidDelta(value)
  return type(value) == "number"
    and value ~= 0
    and value == math.floor(value)
    and math.abs(value) <= RPSTACK_ECONOMY_CONFIG.maxTransactionAmount
end

local function validateOwner(ownerType, ownerId, accountType)
  return isToken(ownerType, 16)
    and isPositiveInteger(ownerId)
    and isToken(accountType, 16)
end

local function toPublicAccount(row)
  return {
    id = row.id,
    ownerType = row.owner_type,
    ownerId = row.owner_id,
    accountType = row.account_type,
    cash = row.cash,
    bank = row.bank,
  }
end

function RPSTACK_ECONOMY_ACCOUNTS.createAccountForOwner(ownerType, ownerId, accountType, cb)
  accountType = accountType or "default"
  if type(cb) ~= "function" or not validateOwner(ownerType, ownerId, accountType) then
    if type(cb) == "function" then cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }) end
    return
  end

  RPSTACK_ECONOMY_REPO.createForOwner(ownerType, ownerId, accountType, function(accountId)
    if not accountId then
      cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
      return
    end

    RPSTACK_ECONOMY_ACCOUNTS.getAccountByOwner(ownerType, ownerId, accountType, cb)
  end)
end

function RPSTACK_ECONOMY_ACCOUNTS.getAccountByOwner(ownerType, ownerId, accountType, cb)
  accountType = accountType or "default"
  if type(cb) ~= "function" or not validateOwner(ownerType, ownerId, accountType) then
    if type(cb) == "function" then cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }) end
    return
  end

  RPSTACK_ECONOMY_REPO.findByOwner(ownerType, ownerId, accountType, function(row)
    cb({ ok = true, account = row and toPublicAccount(row) or nil })
  end)
end

function RPSTACK_ECONOMY_ACCOUNTS.adjustOwnerCash(ownerType, ownerId, accountType, delta, reason, cb)
  accountType = accountType or "default"
  if type(cb) ~= "function"
    or not validateOwner(ownerType, ownerId, accountType)
    or not isValidDelta(delta)
  then
    if type(cb) == "function" then cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }) end
    return
  end

  RPSTACK_ECONOMY_REPO.adjustOwnerCash(ownerType, ownerId, accountType, delta, function(affected)
    if affected ~= 1 then
      cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
      return
    end

    RPSTACK_ECONOMY_REPO.findByOwner(ownerType, ownerId, accountType, function(row)
      if not row then
        cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
        return
      end

      RPSTACK_ECONOMY_REPO.logOwnerTransaction(
        ownerType,
        ownerId,
        accountType,
        delta,
        reason or "adjustOwnerCash",
        row.cash,
        function(transactionId)
          if not transactionId then
            RPSTACK_LOG.error("economy", "owner transaction audit failed", {
              ownerType = ownerType,
              ownerId = ownerId,
              accountType = accountType,
            })
          end
        end
      )

      cb({ ok = true, newCash = row.cash })
    end)
  end)
end

function RPSTACK_ECONOMY_ACCOUNTS.transferCash(
  fromType,
  fromId,
  fromAccount,
  toType,
  toId,
  toAccount,
  amount,
  reason,
  cb
)
  if type(cb) ~= "function"
    or not validateOwner(fromType, fromId, fromAccount)
    or not validateOwner(toType, toId, toAccount)
    or not isPositiveInteger(amount)
    or amount > RPSTACK_ECONOMY_CONFIG.maxTransactionAmount
    or (fromType == toType and fromId == toId and fromAccount == toAccount)
  then
    if type(cb) == "function" then cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }) end
    return
  end

  RPSTACK_ECONOMY_REPO.transferCash(
    fromType,
    fromId,
    fromAccount,
    toType,
    toId,
    toAccount,
    amount,
    function(affected)
      if affected ~= 2 then
        cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
        return
      end

      RPSTACK_ECONOMY_REPO.findByOwner(fromType, fromId, fromAccount, function(source)
        RPSTACK_ECONOMY_REPO.findByOwner(toType, toId, toAccount, function(destination)
          if not source or not destination then
            cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
            return
          end

          local auditReason = reason or "transferCash"
          RPSTACK_ECONOMY_REPO.logOwnerTransaction(
            fromType, fromId, fromAccount, -amount, auditReason, source.cash, function() end
          )
          RPSTACK_ECONOMY_REPO.logOwnerTransaction(
            toType, toId, toAccount, amount, auditReason, destination.cash, function() end
          )

          cb({
            ok = true,
            sourceCash = source.cash,
            destinationCash = destination.cash,
          })
        end)
      end)
    end
  )
end

function RPSTACK_ECONOMY_ACCOUNTS.createAccount(characterId, cb)
  RPSTACK_ECONOMY_ACCOUNTS.createAccountForOwner("character", characterId, "default", cb)
end

function RPSTACK_ECONOMY_ACCOUNTS.adjustCashByCharId(characterId, delta, reason, cb)
  RPSTACK_ECONOMY_ACCOUNTS.adjustOwnerCash(
    "character",
    characterId,
    "default",
    delta,
    reason or "adjustCashByCharId",
    cb
  )
end
