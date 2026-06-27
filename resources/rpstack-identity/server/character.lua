-- All character operations are async (DB-backed).
-- Callers must provide a callback: cb(result)
-- Result shape: { ok = bool, data = ..., error = RPSTACK_ERRORS.* }

local function validateCreatePayload(payload)
  if type(payload) ~= "table" then return false end
  local fn, ln = payload.firstName, payload.lastName
  if type(fn) ~= "string" or #fn < 2 or #fn > 24 then return false end
  if type(ln) ~= "string" or #ln < 2 or #ln > 24 then return false end
  return true
end

RPSTACK_IDENTITY_CHARACTER = {}

-- Create a new character for the player's account.
function RPSTACK_IDENTITY_CHARACTER.createCharacter(src, payload, cb)
  local session = RPSTACK_IDENTITY_SESSION.getSession(src)
  if not session then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
  end

  if not validateCreatePayload(payload) then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end

  RPSTACK_CHARACTER_REPO.create(session.account_id, payload.firstName, payload.lastName, function(char_id)
    if not char_id then
      RPSTACK_LOG.error("identity", "character insert failed", { account_id = session.account_id })
      return cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
    end

    local character = {
      id         = char_id,
      account_id = session.account_id,
      first_name = payload.firstName,
      last_name  = payload.lastName,
    }

    RPSTACK_LOG.info("identity", "character created", {
      source     = src,
      char_id    = char_id,
      account_id = session.account_id,
    })

    TriggerEvent('rpstack:identity:characterCreated', char_id)
    cb({ ok = true, character = character })
  end)
end

-- Load all characters for the player's account.
function RPSTACK_IDENTITY_CHARACTER.getCharacters(src, cb)
  local session = RPSTACK_IDENTITY_SESSION.getSession(src)
  if not session then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
  end

  RPSTACK_CHARACTER_REPO.findByAccount(session.account_id, function(rows)
    cb({ ok = true, characters = rows })
  end)
end

-- Set the active character — verifies ownership.
function RPSTACK_IDENTITY_CHARACTER.selectCharacter(src, char_id, cb)
  local session = RPSTACK_IDENTITY_SESSION.getSession(src)
  if not session then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
  end

  if type(char_id) ~= "number" then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end

  RPSTACK_CHARACTER_REPO.findById(char_id, function(character)
    if not character then
      return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    end

    -- Ownership check — player can only select their own character
    if character.account_id ~= session.account_id then
      RPSTACK_LOG.warn("identity", "character ownership mismatch", {
        source     = src,
        account_id = session.account_id,
        char_id    = char_id,
      })
      return cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    end

    local previous = RPSTACK_IDENTITY_STATE.activeCharacterBySource[src]
    if previous and previous.id ~= character.id then
      TriggerEvent('rpstack:identity:characterUnloaded', {
        source = src,
        characterId = previous.id,
      })
    end

    RPSTACK_IDENTITY_STATE.activeCharacterBySource[src] = character
    TriggerEvent('rpstack:identity:characterLoaded', {
      source = src,
      characterId = character.id,
    })
    cb({ ok = true, character = character })
  end)
end

-- Get the currently active character (in-memory, fast).
function RPSTACK_IDENTITY_CHARACTER.getActiveCharacter(src)
  return RPSTACK_IDENTITY_STATE.activeCharacterBySource[src]
end