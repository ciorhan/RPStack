-- Owns all queries for rpstack_economy_accounts and rpstack_economy_transactions.
-- No other file may query these tables directly.

RPSTACK_ECONOMY_REPO = {}

function RPSTACK_ECONOMY_REPO.findByCharacter(char_id, cb)
  RPSTACK_DB.single(
    "SELECT id, char_id, owner_type, owner_id, account_type, cash, bank FROM `rpstack_economy_accounts` WHERE char_id = ? LIMIT 1",
    { char_id },
    cb
  )
end

function RPSTACK_ECONOMY_REPO.findByOwner(owner_type, owner_id, account_type, cb)
  RPSTACK_DB.single(
    "SELECT id, char_id, owner_type, owner_id, account_type, cash, bank FROM `rpstack_economy_accounts` WHERE owner_type = ? AND owner_id = ? AND account_type = ? LIMIT 1",
    { owner_type, owner_id, account_type },
    cb
  )
end

function RPSTACK_ECONOMY_REPO.create(char_id, cash, bank, cb)
  RPSTACK_DB.insert(
    "INSERT INTO `rpstack_economy_accounts` (char_id, owner_type, owner_id, account_type, cash, bank) VALUES (?, 'character', ?, 'default', ?, ?)",
    { char_id, char_id, cash, bank },
    cb
  )
end

function RPSTACK_ECONOMY_REPO.createForOwner(owner_type, owner_id, account_type, cb)
  RPSTACK_DB.insert(
    "INSERT INTO `rpstack_economy_accounts` (char_id, owner_type, owner_id, account_type, cash, bank) VALUES (NULL, ?, ?, ?, 0, 0) ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)",
    { owner_type, owner_id, account_type },
    cb
  )
end

function RPSTACK_ECONOMY_REPO.updateBalances(char_id, cash, bank, cb)
  RPSTACK_DB.execute(
    "UPDATE `rpstack_economy_accounts` SET cash = ?, bank = ? WHERE char_id = ?",
    { cash, bank, char_id },
    cb
  )
end

function RPSTACK_ECONOMY_REPO.adjustOwnerCash(owner_type, owner_id, account_type, delta, cb)
  RPSTACK_DB.execute(
    "UPDATE `rpstack_economy_accounts` SET cash = cash + ? WHERE owner_type = ? AND owner_id = ? AND account_type = ? AND cash + ? >= 0",
    { delta, owner_type, owner_id, account_type, delta },
    cb
  )
end

function RPSTACK_ECONOMY_REPO.transferCash(from_type, from_id, from_account, to_type, to_id, to_account, amount, cb)
  RPSTACK_DB.execute(
    "UPDATE `rpstack_economy_accounts` AS source JOIN `rpstack_economy_accounts` AS destination ON destination.owner_type = ? AND destination.owner_id = ? AND destination.account_type = ? SET source.cash = source.cash - ?, destination.cash = destination.cash + ? WHERE source.owner_type = ? AND source.owner_id = ? AND source.account_type = ? AND source.cash >= ?",
    { to_type, to_id, to_account, amount, amount, from_type, from_id, from_account, amount },
    cb
  )
end

function RPSTACK_ECONOMY_REPO.logTransaction(char_id, account, amount, reason, balance_after, cb)
  RPSTACK_DB.insert(
    "INSERT INTO `rpstack_economy_transactions` (char_id, owner_type, owner_id, account_type, account, amount, reason, balance_after) VALUES (?, 'character', ?, 'default', ?, ?, ?, ?)",
    { char_id, char_id, account, amount, reason, balance_after },
    cb
  )
end

function RPSTACK_ECONOMY_REPO.logOwnerTransaction(owner_type, owner_id, account_type, amount, reason, balance_after, cb)
  local char_id = owner_type == "character" and owner_id or nil
  RPSTACK_DB.insert(
    "INSERT INTO `rpstack_economy_transactions` (char_id, owner_type, owner_id, account_type, account, amount, reason, balance_after) VALUES (?, ?, ?, ?, 'cash', ?, ?, ?)",
    { char_id, owner_type, owner_id, account_type, amount, reason, balance_after },
    cb
  )
end
