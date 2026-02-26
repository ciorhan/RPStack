local function getIdentifiers(src)
  local out = {}
  for i = 0, GetNumPlayerIdentifiers(src) - 1 do
    local id = GetPlayerIdentifier(src, i)
    if id then out[#out + 1] = id end
  end
  return out
end

local function pickPrimaryIdentifier(identifiers)
  -- Prefer license if present; otherwise first identifier.
  for _, v in ipairs(identifiers) do
    if string.sub(v, 1, 8) == "license:" then
      return v
    end
  end
  return identifiers[1]
end

RPSTACK_IDENTITY_SESSION = {}

function RPSTACK_IDENTITY_SESSION.onPlayerJoining(src)
  local identifiers = getIdentifiers(src)
  local primary = pickPrimaryIdentifier(identifiers)

  local session = {
    source = src,
    name = GetPlayerName(src) or ("player_" .. tostring(src)),
    identifiers = identifiers,
    primaryIdentifier = primary,
    joinedAt = os.time(),
  }

  RPSTACK_IDENTITY_STATE.sessions[src] = session

  RPSTACK_LOG.info("identity", "player session created", {
    source = src,
    primary = primary or "none",
    name = session.name
  })

  return session
end

function RPSTACK_IDENTITY_SESSION.onPlayerDropped(src, reason)
  local session = RPSTACK_IDENTITY_STATE.sessions[src]
  RPSTACK_IDENTITY_STATE.sessions[src] = nil
  RPSTACK_IDENTITY_STATE.activeCharacterBySource[src] = nil

  RPSTACK_LOG.info("identity", "player session dropped", {
    source = src,
    reason = reason or "unknown",
    primary = session and session.primaryIdentifier or "none"
  })
end

function RPSTACK_IDENTITY_SESSION.getSession(src)
  return RPSTACK_IDENTITY_STATE.sessions[src]
end