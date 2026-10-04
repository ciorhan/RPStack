-- rpstack-vorp-bridge/server/vorp.lua
-- The only place that calls VORP Core. Every call is pcall-wrapped and reads
-- VORP server objects fresh (ADR-011): no caching of user or character tables.

RPSTACK_BRIDGE_VORP = {}

local function getCore()
  local ok, core = pcall(function()
    return exports[BRIDGE_VORP.RESOURCE]:GetCore()
  end)
  if not ok or type(core) ~= "table" then
    RPSTACK_LOG.error("vorp-bridge", "GetCore failed", { error = tostring(core) })
    return nil
  end
  return core
end

-- Converts a VORP character table (vorp_core/server/class/character.lua:531-562)
-- into the bridge's public character shape. Returns nil when no character is active
-- (VORP returns {} in that case, vorp_core/server/class/user.lua:176-182).
local function toCharacter(vorpCharacter)
  if type(vorpCharacter) ~= "table" then return nil end
  local id = tonumber(vorpCharacter.charIdentifier)
  if not id or id <= 0 or id ~= math.floor(id) then return nil end
  return {
    id = id,
    firstname = tostring(vorpCharacter.firstname or ""),
    lastname = tostring(vorpCharacter.lastname or ""),
  }
end

RPSTACK_BRIDGE_VORP.toCharacter = toCharacter

-- Returns ok:boolean, character|nil.
-- ok = false means VORP could not be queried (INTERNAL); ok = true with nil means no active character.
function RPSTACK_BRIDGE_VORP.getActiveCharacter(src)
  local core = getCore()
  if not core then return false, nil end

  local ok, result = pcall(function()
    local user = core.getUser(src) -- vorp_core/server/apicontroller.lua:45-52
    if not user then return nil end
    return toCharacter(user.getUsedCharacter) -- snapshot taken at GetUser() time
  end)
  if not ok then
    RPSTACK_LOG.error("vorp-bridge", "getUser failed", { source = src, error = tostring(result) })
    return false, nil
  end
  return true, result
end

-- Returns ok:boolean, character|nil for a character that is active on an online player.
function RPSTACK_BRIDGE_VORP.getOnlineCharacterById(characterId)
  local core = getCore()
  if not core then return false, nil end

  local ok, result = pcall(function()
    local user = core.getUserByCharId(characterId) -- vorp_core/server/apicontroller.lua:54-62
    if not user then return nil end
    local character = toCharacter(user.getUsedCharacter)
    if not character or character.id ~= characterId then return nil end
    return character
  end)
  if not ok then
    RPSTACK_LOG.error("vorp-bridge", "getUserByCharId failed", { characterId = characterId, error = tostring(result) })
    return false, nil
  end
  return true, result
end
