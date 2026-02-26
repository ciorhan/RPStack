RPSTACK_IDENTITY_STATE = RPSTACK_IDENTITY_STATE or {}

-- sessions[source] = { source, identifiers, name, joinedAt, characterId? }
RPSTACK_IDENTITY_STATE.sessions = RPSTACK_IDENTITY_STATE.sessions or {}

-- characters[charId] = { id, ownerIdentifier, firstName, lastName, createdAt }
-- NOTE: In v0 this is in-memory only. Persistence comes next module.
RPSTACK_IDENTITY_STATE.characters = RPSTACK_IDENTITY_STATE.characters or {}

-- activeCharacterBySource[source] = charId
RPSTACK_IDENTITY_STATE.activeCharacterBySource = RPSTACK_IDENTITY_STATE.activeCharacterBySource or {}