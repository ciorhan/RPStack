-- Owns all queries against the `rpstack_accounts` table.
-- No other file may query this table directly.

RPSTACK_ACCOUNT_REPO = {}

-- Find an account by its primary identifier.
-- cb(account | nil)
function RPSTACK_ACCOUNT_REPO.findByIdentifier(identifier, cb)
  RPSTACK_DB.single(
    "SELECT id, primary_identifier, name, created_at FROM `rpstack_accounts` WHERE primary_identifier = ? LIMIT 1",
    { identifier },
    cb
  )
end

-- Create a new account. cb(account_id | nil)
function RPSTACK_ACCOUNT_REPO.create(identifier, name, cb)
  RPSTACK_DB.insert(
    "INSERT INTO `rpstack_accounts` (primary_identifier, name) VALUES (?, ?)",
    { identifier, name },
    cb
  )
end