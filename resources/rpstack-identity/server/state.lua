RPSTACK_IDENTITY_STATE = RPSTACK_IDENTITY_STATE or {}

-- sessions[source] = { source, account_id, name, primaryIdentifier, joinedAt }
RPSTACK_IDENTITY_STATE.sessions = RPSTACK_IDENTITY_STATE.sessions or {}

-- activeCharacterBySource[source] = character row (table) or nil
RPSTACK_IDENTITY_STATE.activeCharacterBySource = RPSTACK_IDENTITY_STATE.activeCharacterBySource or {}