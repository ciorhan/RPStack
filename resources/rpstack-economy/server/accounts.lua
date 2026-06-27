-- rpstack-economy/server/accounts.lua  (additions — merge into your existing file)
--
-- Fixes from v1:
--   Table name: rpstack_economy_accounts  (not economy_accounts)
--   Column name: char_id                  (not character_id)
--   Queries now use RPSTACK_ECONOMY_REPO pattern matching your existing repo style
--     rather than calling exports['rpstack-persistence'] directly.
--
-- Add these three functions to your RPSTACK_ECONOMY_ACCOUNTS table.
-- Replace your existing createAccount(characterId) body with the wrapper at the bottom.

RPSTACK_ECONOMY_ACCOUNTS = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal: create an account for any owner type
-- ─────────────────────────────────────────────────────────────────────────────
function RPSTACK_ECONOMY_ACCOUNTS.createAccountForOwner(ownerType, ownerId, accountType, cb)
  if type(ownerType) ~= "string" or #ownerType == 0 then
    if cb then cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }) end
    return
  end
  if type(ownerId) ~= "number" or ownerId <= 0 then
    if cb then cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }) end
    return
  end

  accountType = accountType or "default"

  -- Guard: do not create duplicates
  RPSTACK_ECONOMY_ACCOUNTS.getAccountByOwner(ownerType, ownerId, accountType, function(existing)
    if existing.ok and existing.account then
      if cb then cb({ ok = true, account = existing.account }) end
      return
    end

    MySQL.insert(
      "INSERT INTO `rpstack_economy_accounts` (`char_id`, `owner_type`, `owner_id`, `account_type`, `cash`, `bank`) VALUES (NULL, ?, ?, ?, 0, 0)",
      { ownerType, ownerId, accountType },
      function(insertId)
        if not insertId then
          RPSTACK_LOG.error("economy", "createAccountForOwner insert failed", {
            ownerType = ownerType, ownerId = ownerId, accountType = accountType
          })
          if cb then cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL }) end
          return
        end

        local account = {
          id          = insertId,
          ownerType   = ownerType,
          ownerId     = ownerId,
          accountType = accountType,
          cash        = 0,
          bank        = 0,
        }

        RPSTACK_LOG.info("economy", "account created", {
          ownerType = ownerType, ownerId = ownerId, accountType = accountType, accountId = insertId
        })

        if cb then cb({ ok = true, account = account }) end
      end
    )
  end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal: look up an account by owner type + owner id
-- ─────────────────────────────────────────────────────────────────────────────
function RPSTACK_ECONOMY_ACCOUNTS.getAccountByOwner(ownerType, ownerId, accountType, cb)
  if type(ownerType) ~= "string" or type(ownerId) ~= "number" then
    if cb then cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }) end
    return
  end

  accountType = accountType or "default"

  MySQL.query(
    "SELECT `id`, `owner_type`, `owner_id`, `account_type`, `cash`, `bank` FROM `rpstack_economy_accounts` WHERE `owner_type` = ? AND `owner_id` = ? AND `account_type` = ? LIMIT 1",
    { ownerType, ownerId, accountType },
    function(rows)
      if not rows or #rows == 0 then
        if cb then cb({ ok = true, account = nil }) end
        return
      end
      local row = rows[1]
      if cb then cb({
        ok = true,
        account = {
          id          = row.id,
          ownerType   = row.owner_type,
          ownerId     = row.owner_id,
          accountType = row.account_type,
          cash        = row.cash,
          bank        = row.bank,
        }
      }) end
    end
  )
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Adjust cash balance for any owner — used by treasury deposit/withdraw
-- delta is positive (add) or negative (subtract)
-- Guards against negative balance on subtract
-- ─────────────────────────────────────────────────────────────────────────────
function RPSTACK_ECONOMY_ACCOUNTS.adjustOwnerCash(ownerType, ownerId, accountType, delta, reason, cb)
  accountType = accountType or "default"

  RPSTACK_ECONOMY_ACCOUNTS.getAccountByOwner(ownerType, ownerId, accountType, function(result)
    if not result.ok or not result.account then
      if cb then cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
      return
    end

    local current = result.account.cash
    local newCash = current + delta

    if newCash < 0 then
      if cb then cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }) end
      return
    end

    MySQL.update(
      "UPDATE `rpstack_economy_accounts` SET `cash` = ? WHERE `owner_type` = ? AND `owner_id` = ? AND `account_type` = ?",
      { newCash, ownerType, ownerId, accountType },
      function(affected)
        if not affected or affected == 0 then
          if cb then cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL }) end
          return
        end

        -- Log to transaction table for ledger visibility
        MySQL.insert(
          "INSERT INTO `rpstack_economy_transactions` (`char_id`, `account`, `amount`, `reason`, `balance_after`) VALUES (NULL, 'cash', ?, ?, ?)",
          { delta, reason or "adjustOwnerCash", newCash },
          function() end -- fire and forget
        )

        if cb then cb({ ok = true, newCash = newCash }) end
      end
    )
  end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Backwards-compatible wrapper — replace your existing createAccount body
-- ─────────────────────────────────────────────────────────────────────────────
function RPSTACK_ECONOMY_ACCOUNTS.createAccount(characterId, cb)
  RPSTACK_ECONOMY_ACCOUNTS.createAccountForOwner("character", characterId, "default", cb)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Adjust cash balance by character id (not source).
-- Used by faction treasury and any system that operates on offline characters.
-- delta: positive = add, negative = subtract.
-- Guards against negative balance.
-- ─────────────────────────────────────────────────────────────────────────────
function RPSTACK_ECONOMY_ACCOUNTS.adjustCashByCharId(characterId, delta, reason, cb)
  MySQL.query(
    "SELECT `id`, `cash` FROM `rpstack_economy_accounts` WHERE `char_id` = ? AND `owner_type` = 'character' LIMIT 1",
    { characterId },
    function(rows)
      if not rows or #rows == 0 then
        if cb then cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
        return
      end

      local row     = rows[1]
      local newCash = row.cash + delta

      if newCash < 0 then
        if cb then cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }) end
        return
      end

      MySQL.update(
        "UPDATE `rpstack_economy_accounts` SET `cash` = ? WHERE `id` = ?",
        { newCash, row.id },
        function(affected)
          if not affected or affected == 0 then
            if cb then cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL }) end
            return
          end

          MySQL.insert(
            "INSERT INTO `rpstack_economy_transactions` (`char_id`, `account`, `amount`, `reason`, `balance_after`) VALUES (?, 'cash', ?, ?, ?)",
            { characterId, delta, reason or "adjustCash", newCash },
            function() end
          )

          if cb then cb({ ok = true, newCash = newCash }) end
        end
      )
    end
  )
end