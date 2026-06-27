-- ledger.lua
-- ALL money mutations go through RPSTACK_LEDGER.apply().
-- No other code may call RPSTACK_ECONOMY_REPO.updateBalances() directly.

RPSTACK_LEDGER = {}

local function validateAmount(amount)
  return type(amount) == "number"
    and amount > 0
    and math.floor(amount) == amount
    and amount <= RPSTACK_ECONOMY_CONFIG.maxTransactionAmount
end

local function validateAccount(account)
  return account == "cash" or account == "bank"
end

-- Apply a signed delta to a character's balance.
-- account: "cash" | "bank"
-- delta:   positive = add money, negative = remove money
-- reason:  string description for the audit log
-- cb({ ok, cash, bank, error })
function RPSTACK_LEDGER.apply(char_id, account, delta, reason, cb)
  if not validateAccount(account) then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end
  if type(delta) ~= "number" or delta == 0 then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end
  if math.abs(delta) > RPSTACK_ECONOMY_CONFIG.maxTransactionAmount then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end

  -- Fetch current balances
  RPSTACK_ECONOMY_REPO.findByCharacter(char_id, function(row)
    if not row then
      return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    end

    local new_cash = row.cash
    local new_bank = row.bank

    if account == "cash" then
      new_cash = new_cash + delta
    else
      new_bank = new_bank + delta
    end

    -- Prevent negative balances
    if new_cash < 0 or new_bank < 0 then
      return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    end

    local balance_after = account == "cash" and new_cash or new_bank

    -- Write new balances
    RPSTACK_ECONOMY_REPO.updateBalances(char_id, new_cash, new_bank, function(affected)
      if affected == 0 then
        return cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
      end

      -- Audit log — fire and forget (non-blocking)
      RPSTACK_ECONOMY_REPO.logTransaction(char_id, account, delta, reason, balance_after, function() end)

      RPSTACK_LOG.info("economy", "ledger apply", {
        char_id  = char_id,
        account  = account,
        delta    = delta,
        reason   = reason,
        cash     = new_cash,
        bank     = new_bank,
      })

      cb({ ok = true, cash = new_cash, bank = new_bank })
    end)
  end)
end