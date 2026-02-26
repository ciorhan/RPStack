local function newCharId()
  -- v0: simple monotonic id. Later: DB id/UUID.
  RPSTACK_IDENTITY_STATE._charSeq = (RPSTACK_IDENTITY_STATE._charSeq or 1000) + 1
  return RPSTACK_IDENTITY_STATE._charSeq
end

local function validateCreatePayload(payload)
  if type(payload) ~= "table" then return false, RPSTACK_ERRORS.VALIDATION_FAILED end

  local firstName = payload.firstName
  local lastName  = payload.lastName

  if type(firstName) ~= "string" or #firstName < 2 or #firstName > 24 then
    return false, RPSTACK_ERRORS.VALIDATION_FAILED
  end
  if type(lastName) ~= "string" or #lastName < 2 or #lastName > 24 then
    return false, RPSTACK_ERRORS.VALIDATION_FAILED
  end

  return true, RPSTACK_ERRORS.OK
end

RPSTACK_IDENTITY_CHARACTER = {}

function RPSTACK_IDENTITY_CHARACTER.createCharacter(src, payload)
  local session = RPSTACK_IDENTITY_SESSION.getSession(src)
  if not session then
    return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND }
  end
  if not session.primaryIdentifier then
    return { ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }
  end

  local ok, err = validateCreatePayload(payload)
  if not ok then
    return { ok = false, error = err }
  end

  local charId = newCharId()
  local character = {
    id = charId,
    ownerIdentifier = session.primaryIdentifier,
    firstName = payload.firstName,
    lastName = payload.lastName,
    createdAt = os.time(),
  }

  RPSTACK_IDENTITY_STATE.characters[charId] = character
  RPSTACK_IDENTITY_STATE.activeCharacterBySource[src] = charId

  -- Audit-ish log (later: write into economy/audit module)
  RPSTACK_LOG.info("identity", "character created", {
    source = src,
    charId = charId,
    owner = session.primaryIdentifier
  })

  return { ok = true, character = character }
end

function RPSTACK_IDENTITY_CHARACTER.getActiveCharacter(src)
  local charId = RPSTACK_IDENTITY_STATE.activeCharacterBySource[src]
  if not charId then return { ok = true, character = nil } end
  return { ok = true, character = RPSTACK_IDENTITY_STATE.characters[charId] }
end

function RPSTACK_IDENTITY_CHARACTER.setActiveCharacter(src, charId)
  if RPSTACK_IDENTITY_STATE.characters[charId] == nil then
    return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND }
  end
  RPSTACK_IDENTITY_STATE.activeCharacterBySource[src] = charId
  return { ok = true }
end