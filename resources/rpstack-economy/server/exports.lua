-- All exports require an active character on the source player.
-- Callers must handle async results via callback.

local function getChar(src)
  return exports['rpstack-identity']['rpstack:identity:getActiveCharacter'](src).character
end

exports('rpstack:economy:getBalance', function(src)
  local char = getChar(src)
  if not char then return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND } end

  -- Synchronous read from DB via blocking oxmysql (acceptable for balance reads)
  local row = RPSTACK_ECONOMY_REPO.findByCharacter(char.id, function(row)
    return row
  end)
  -- Note: use the async export below for non-blocking reads in production code
  return { ok = false, error = RPSTACK_ERRORS.INTERNAL }
end)

-- Async balance read (preferred)
exports('rpstack:economy:getBalanceAsync', function(src, cb)
  local char = getChar(src)
  if not char then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end

  RPSTACK_ECONOMY_REPO.findByCharacter(char.id, function(row)
    if not row then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
    cb({ ok = true, cash = row.cash, bank = row.bank })
  end)
end)

exports('rpstack:economy:addMoney', function(src, account, amount, reason, cb)
  local char = getChar(src)
  if not char then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
  if type(amount) ~= "number" or amount <= 0 then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end
  RPSTACK_LEDGER.apply(char.id, account, amount, reason or "addMoney", cb)
end)

exports('rpstack:economy:removeMoney', function(src, account, amount, reason, cb)
  local char = getChar(src)
  if not char then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
  if type(amount) ~= "number" or amount <= 0 then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end
  RPSTACK_LEDGER.apply(char.id, account, -amount, reason or "removeMoney", cb)
end)

exports('rpstack:economy:deposit', function(src, amount, reason, cb)
  local char = getChar(src)
  if not char then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
  -- deposit = remove cash, add bank (two ledger entries)
  RPSTACK_LEDGER.apply(char.id, "cash", -amount, reason or "deposit", function(r1)
    if not r1.ok then return cb(r1) end
    RPSTACK_LEDGER.apply(char.id, "bank", amount, reason or "deposit", cb)
  end)
end)

exports('rpstack:economy:withdraw', function(src, amount, reason, cb)
  local char = getChar(src)
  if not char then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
  -- withdraw = remove bank, add cash
  RPSTACK_LEDGER.apply(char.id, "bank", -amount, reason or "withdraw", function(r1)
    if not r1.ok then return cb(r1) end
    RPSTACK_LEDGER.apply(char.id, "cash", amount, reason or "withdraw", cb)
  end)
end)