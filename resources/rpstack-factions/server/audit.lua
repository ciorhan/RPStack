-- rpstack-factions/server/audit.lua
-- Async, non-blocking audit log writer.
-- NEVER awaited by callers. If the insert fails, we warn and move on.
-- The authoritative action already completed before this runs.

RPSTACK_FACTIONS_AUDIT = {}

function RPSTACK_FACTIONS_AUDIT.log(factionId, actorCharId, action, payload)
  -- Encode payload to a single-line JSON string.
  -- json.encode is available globally in CfxLua (CitizenFX built-in).
  local payloadJson = ""
  if payload then
    local ok, encoded = pcall(json.encode, payload)
    if ok then payloadJson = encoded end
  end

  -- Fire into a thread so the caller is never blocked
  CreateThread(function()
    local ok, err = pcall(function()
      RPSTACK_FACTIONS_REPO.insertAudit(factionId, actorCharId, action, payloadJson)
    end)
    if not ok then
      RPSTACK_LOG.warn("factions", "audit write failed", {
        factionId = factionId,
        action    = action,
        error     = tostring(err),
      })
    end
  end)
end