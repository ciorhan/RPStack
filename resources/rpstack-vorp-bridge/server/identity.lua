-- rpstack-vorp-bridge/server/identity.lua
-- Identity domain over VORP: active character lookup (N1), character by id (N2),
-- and load/unload lifecycle events (N3). See docs/integration/vorp-analysis.md §8.

RPSTACK_BRIDGE_IDENTITY = {}

local function isPositiveInteger(value)
  return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function isValidCharacterId(value)
  return isPositiveInteger(value) and value <= RPSTACK_BRIDGE_CONFIG.max_character_id
end

-- A source is valid only if it is a positive integer for a connected player.
local function isValidSource(src)
  return isPositiveInteger(src) and GetPlayerName(src) ~= nil
end

RPSTACK_BRIDGE_IDENTITY.isValidSource = isValidSource

-- ── N1 ────────────────────────────────────────────────────────────────────────

function RPSTACK_BRIDGE_IDENTITY.getActiveCharacter(src)
  if not isValidSource(src) then
    return { ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }
  end

  local ok, character = RPSTACK_BRIDGE_VORP.getActiveCharacter(src)
  if not ok then
    return { ok = false, error = RPSTACK_ERRORS.INTERNAL }
  end
  if not character then
    return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND }
  end
  return { ok = true, character = character }
end

-- ── N2 ────────────────────────────────────────────────────────────────────────

function RPSTACK_BRIDGE_IDENTITY.getCharacterById(characterId, cb)
  if type(cb) ~= "function" then return end
  if not isValidCharacterId(characterId) then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end

  local ok, online = RPSTACK_BRIDGE_VORP.getOnlineCharacterById(characterId)
  if ok and online then
    online.online = true
    cb({ ok = true, character = online })
    return
  end

  local readyOk, ready = pcall(function()
    return exports['rpstack-persistence']:isPersistenceReady()
  end)
  if not readyOk or not ready then
    RPSTACK_LOG.warn("vorp-bridge", "offline character lookup before persistence ready", {
      characterId = characterId,
    })
    cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
    return
  end

  local queryOk, err = pcall(RPSTACK_BRIDGE_REPO.findCharacterById, characterId, function(row)
    if not row then
      cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
      return
    end
    local character = RPSTACK_BRIDGE_VORP.toCharacter({
      charIdentifier = row.charidentifier,
      firstname = row.firstname,
      lastname = row.lastname,
    })
    if not character then
      cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
      return
    end
    character.online = false
    cb({ ok = true, character = character })
  end)
  if not queryOk then
    RPSTACK_LOG.error("vorp-bridge", "offline character lookup failed", {
      characterId = characterId,
      error = tostring(err),
    })
    cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
  end
end

-- ── N3 ────────────────────────────────────────────────────────────────────────

local function emitUnloaded(src, characterId)
  RPSTACK_LOG.info("vorp-bridge", "character unloaded", { source = src, characterId = characterId })
  TriggerEvent(BRIDGE_EVENTS.CHARACTER_UNLOADED, { characterId = characterId, source = src })
end

local function emitLoaded(src, characterId)
  RPSTACK_LOG.info("vorp-bridge", "character loaded", { source = src, characterId = characterId })
  TriggerEvent(BRIDGE_EVENTS.CHARACTER_LOADED, { characterId = characterId, source = src })
end

-- Handler for vorp_core's server-local vorp:SelectedCharacter(source, characterTable).
-- The payload is a hint only: the active character is re-read from VORP (ADR-011).
function RPSTACK_BRIDGE_IDENTITY.onSelectedCharacter(invokingResource, src, payload)
  if invokingResource ~= BRIDGE_VORP.RESOURCE then
    RPSTACK_LOG.warn("vorp-bridge", "ignored SelectedCharacter not triggered by vorp_core", {
      invoker = tostring(invokingResource),
      source = tostring(src),
    })
    return
  end

  src = tonumber(src)
  if not isValidSource(src) then
    RPSTACK_LOG.warn("vorp-bridge", "SelectedCharacter with invalid source", { source = tostring(src) })
    return
  end

  local ok, character = RPSTACK_BRIDGE_VORP.getActiveCharacter(src)
  if not ok or not character then
    RPSTACK_LOG.warn("vorp-bridge", "SelectedCharacter but VORP reports no active character", { source = src })
    return
  end

  local payloadId = type(payload) == "table" and tonumber(payload.charIdentifier) or nil
  if payloadId ~= character.id then
    RPSTACK_LOG.warn("vorp-bridge", "SelectedCharacter payload differs from VORP state; using VORP state", {
      source = src,
      payloadId = tostring(payloadId),
      characterId = character.id,
    })
  end

  local previous = RPSTACK_BRIDGE_STATE.charBySource[src]
  if previous == character.id then
    return
  end
  if previous then
    emitUnloaded(src, previous)
  end

  RPSTACK_BRIDGE_STATE.charBySource[src] = character.id
  emitLoaded(src, character.id)
end

function RPSTACK_BRIDGE_IDENTITY.onPlayerDropped(src)
  src = tonumber(src)
  if not src then return end
  local characterId = RPSTACK_BRIDGE_STATE.charBySource[src]
  RPSTACK_BRIDGE_STATE.charBySource[src] = nil
  if characterId then
    emitUnloaded(src, characterId)
  end
end

-- Rebuilds charBySource from VORP after a bridge (re)start. Emits no events:
-- consumers that start later catch up through getActiveCharacter.
function RPSTACK_BRIDGE_IDENTITY.rebuild()
  local count = 0
  for _, playerId in ipairs(GetPlayers()) do
    local src = tonumber(playerId)
    if src then
      local ok, character = RPSTACK_BRIDGE_VORP.getActiveCharacter(src)
      if ok and character then
        RPSTACK_BRIDGE_STATE.charBySource[src] = character.id
        count = count + 1
      end
    end
  end
  return count
end
