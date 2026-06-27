-- Owns all queries for rpstack_economy_accounts and rpstack_economy_transactions.
-- No other file may query these tables directly.

RPSTACK_ECONOMY_REPO = {}

-- Get economy account for a character. cb(row | nil)
function RPSTACK_ECONOMY_REPO.findByCharacter(char_id, cb)
  RPSTACK_DB.single(
    "SELECT id, char_id, cash, bank FROM `rpstack_economy_accounts` WHERE char_id = ? LIMIT 1",
    { char_id },
    cb
  )
end

-- Create economy account for a new character. cb(id | nil)
function RPSTACK_ECONOMY_REPO.create(char_id, cash, bank, cb)
  RPSTACK_DB.insert(
    "INSERT INTO `rpstack_economy_accounts` (char_id, cash, bank) VALUES (?, ?, ?)",
    { char_id, cash, bank },
    cb
  )
end

-- Update balances atomically. cb(affected)
-- Only called from ledger.lua — never directly.
function RPSTACK_ECONOMY_REPO.updateBalances(char_id, cash, bank, cb)
  RPSTACK_DB.execute(
    "UPDATE `rpstack_economy_accounts` SET cash = ?, bank = ? WHERE char_id = ?",
    { cash, bank, char_id },
    cb
  )
end

-- Insert a transaction record. cb(id | nil)
function RPSTACK_ECONOMY_REPO.logTransaction(char_id, account, amount, reason, balance_after, cb)
  RPSTACK_DB.insert(
    [[INSERT INTO `rpstack_economy_transactions`
      (char_id, account, amount, reason, balance_after)
      VALUES (?, ?, ?, ?, ?)]],
    { char_id, account, amount, reason, balance_after },
    cb
  )
end