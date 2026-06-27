-- Owns all queries against the `rpstack_characters` table.
-- No other file may query this table directly.

RPSTACK_CHARACTER_REPO = {}

-- Get all characters belonging to an account. cb(rows)
function RPSTACK_CHARACTER_REPO.findByAccount(account_id, cb)
  RPSTACK_DB.query(
    "SELECT id, account_id, first_name, last_name, created_at FROM `rpstack_characters` WHERE account_id = ? ORDER BY created_at ASC",
    { account_id },
    cb
  )
end

-- Get a single character by id. cb(character | nil)
function RPSTACK_CHARACTER_REPO.findById(char_id, cb)
  RPSTACK_DB.single(
    "SELECT id, account_id, first_name, last_name, created_at FROM `rpstack_characters` WHERE id = ? LIMIT 1",
    { char_id },
    cb
  )
end

-- Create a new character. cb(char_id | nil)
function RPSTACK_CHARACTER_REPO.create(account_id, first_name, last_name, cb)
  RPSTACK_DB.insert(
    "INSERT INTO `rpstack_characters` (account_id, first_name, last_name) VALUES (?, ?, ?)",
    { account_id, first_name, last_name },
    cb
  )
end

-- Delete a character by id (must verify ownership before calling). cb(affected)
function RPSTACK_CHARACTER_REPO.delete(char_id, account_id, cb)
  RPSTACK_DB.execute(
    "DELETE FROM `rpstack_characters` WHERE id = ? AND account_id = ?",
    { char_id, account_id },
    cb
  )
end