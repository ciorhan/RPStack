-- All exports are async. Callers must provide a callback.
-- Never call balance mutations directly — always go through these exports.

local function getChar(src)
  return exports['rpstack-identity']['rpstack:identity:getActiveCharacter'](src).character
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