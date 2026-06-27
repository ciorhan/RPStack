-- All exports are async. Callers must provide a callback.
-- Never call balance mutations directly — always go through these exports.

local function localCallback(callback)
  if callback == nil then return nil end
  return function(result)
    callback(result)
  end
end

local function getChar(src)
  local identity = exports['rpstack-identity']
  local result = identity['rpstack:identity:getActiveCharacter'](identity, src)
  return result and result.character or nil
end

-- Get current balances. cb({ ok, cash, bank })
exports('rpstack:economy:getBalance', function(src, cb)
  local char = getChar(src)
  if not char then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end

  RPSTACK_ECONOMY_REPO.findByCharacter(char.id, function(row)
    if not row then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
    cb({ ok = true, cash = row.cash, bank = row.bank })
  end)
end)

-- Add money to cash or bank. account = "cash" | "bank"
exports('rpstack:economy:addMoney', function(src, account, amount, reason, cb)
  local char = getChar(src)
  if not char then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
  if type(amount) ~= "number" or amount <= 0 then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end
  RPSTACK_LEDGER.apply(char.id, account, amount, reason or "addMoney", cb)
end)

-- Remove money from cash or bank.
exports('rpstack:economy:removeMoney', function(src, account, amount, reason, cb)
  local char = getChar(src)
  if not char then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
  if type(amount) ~= "number" or amount <= 0 then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end
  RPSTACK_LEDGER.apply(char.id, account, -amount, reason or "removeMoney", cb)
end)

-- Move money from cash to bank.
exports('rpstack:economy:deposit', function(src, amount, reason, cb)
  local char = getChar(src)
  if not char then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
  RPSTACK_LEDGER.apply(char.id, "cash", -amount, reason or "deposit", function(r1)
    if not r1.ok then return cb(r1) end
    RPSTACK_LEDGER.apply(char.id, "bank", amount, reason or "deposit", cb)
  end)
end)

-- Move money from bank to cash.
exports('rpstack:economy:withdraw', function(src, amount, reason, cb)
  local char = getChar(src)
  if not char then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
  RPSTACK_LEDGER.apply(char.id, "bank", -amount, reason or "withdraw", function(r1)
    if not r1.ok then return cb(r1) end
    RPSTACK_LEDGER.apply(char.id, "cash", amount, reason or "withdraw", cb)
  end)
end)
 
-- Create an economy account for any owning entity (faction, town, etc.)
exports('rpstack:economy:createAccountForOwner', function(ownerType, ownerId, accountType, cb)
  RPSTACK_ECONOMY_ACCOUNTS.createAccountForOwner(ownerType, ownerId, accountType, localCallback(cb))
end)
 
-- Retrieve an account by owner
exports('rpstack:economy:getAccountByOwner', function(ownerType, ownerId, accountType, cb)
  RPSTACK_ECONOMY_ACCOUNTS.getAccountByOwner(ownerType, ownerId, accountType, localCallback(cb))
end)
 
-- Adjust cash balance for any non-character owner (faction treasury, etc.)
-- delta: positive = add, negative = subtract
exports('rpstack:economy:adjustOwnerCash', function(ownerType, ownerId, accountType, delta, reason, cb)
  RPSTACK_ECONOMY_ACCOUNTS.adjustOwnerCash(ownerType, ownerId, accountType, delta, reason, localCallback(cb))
end)
 
-- Adjust cash by character id — for systems operating without a live source (treasury, automation)
exports('rpstack:economy:adjustCashByCharId', function(characterId, delta, reason, cb)
  RPSTACK_ECONOMY_ACCOUNTS.adjustCashByCharId(characterId, delta, reason, localCallback(cb))
end)

-- Transfer cash between two owner accounts with one atomic balance update.
exports('rpstack:economy:transferCash', function(
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
  RPSTACK_ECONOMY_ACCOUNTS.transferCash(
    fromType,
    fromId,
    fromAccount,
    toType,
    toId,
    toAccount,
    amount,
    reason,
    localCallback(cb)
  )
end)
