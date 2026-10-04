-- rpstack-vorp-bridge/server/exports.lua
-- Public exports. Thin wrappers only. Names and result shapes match rpstack-identity
-- so callers only change the target resource name. Bracket calls must pass the
-- export proxy as the first argument (CLAUDE.md "Export patterns").

local function localCallback(callback)
  if callback == nil then return nil end
  return function(result)
    callback(result)
  end
end

exports('rpstack:identity:getActiveCharacter', function(src)
  return RPSTACK_BRIDGE_IDENTITY.getActiveCharacter(src)
end)

exports('rpstack:identity:getCharacterById', function(characterId, cb)
  RPSTACK_BRIDGE_IDENTITY.getCharacterById(characterId, localCallback(cb))
end)
