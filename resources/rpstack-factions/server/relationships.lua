-- Faction-to-faction relationship management.

RPSTACK_FACTIONS_RELATIONSHIPS = {}

local VALID_STATUS = {
  [FACTION_RELATIONSHIP.ALLY] = true,
  [FACTION_RELATIONSHIP.NEUTRAL] = true,
  [FACTION_RELATIONSHIP.HOSTILE] = true,
}

local function isPositiveInteger(value)
  return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function canonicalPair(factionAId, factionBId)
  if factionAId < factionBId then return factionAId, factionBId end
  return factionBId, factionAId
end

function RPSTACK_FACTIONS_RELATIONSHIPS.getRelationship(factionAId, factionBId)
  if not isPositiveInteger(factionAId)
    or not isPositiveInteger(factionBId)
    or not RPSTACK_FACTIONS_STATE.factions[factionAId]
    or not RPSTACK_FACTIONS_STATE.factions[factionBId]
  then
    return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND }
  end
  if factionAId == factionBId then
    return { ok = true, status = FACTION_RELATIONSHIP.ALLY }
  end

  local relMap = RPSTACK_FACTIONS_STATE.relationships[factionAId]
  return {
    ok = true,
    status = relMap and relMap[factionBId] or FACTION_RELATIONSHIP.NEUTRAL,
  }
end

function RPSTACK_FACTIONS_RELATIONSHIPS.getFactionAllies(factionId)
  return RPSTACK_FACTIONS_RELATIONSHIPS._getByStatus(
    factionId,
    FACTION_RELATIONSHIP.ALLY
  )
end

function RPSTACK_FACTIONS_RELATIONSHIPS.getFactionHostiles(factionId)
  return RPSTACK_FACTIONS_RELATIONSHIPS._getByStatus(
    factionId,
    FACTION_RELATIONSHIP.HOSTILE
  )
end

function RPSTACK_FACTIONS_RELATIONSHIPS._getByStatus(factionId, status)
  if not isPositiveInteger(factionId) or not RPSTACK_FACTIONS_STATE.factions[factionId] then
    return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND }
  end

  local relMap = RPSTACK_FACTIONS_STATE.relationships[factionId] or {}
  local list = {}
  for otherFactionId, currentStatus in pairs(relMap) do
    if currentStatus == status then
      local faction = RPSTACK_FACTIONS_STATE.factions[otherFactionId]
      if faction then list[#list + 1] = faction end
    end
  end
  return { ok = true, factions = list }
end

function RPSTACK_FACTIONS_RELATIONSHIPS.setRelationship(
  factionAId,
  factionBId,
  status,
  actorCharId,
  cb
)
  if type(cb) ~= "function" then return end
  if not isPositiveInteger(factionAId)
    or not isPositiveInteger(factionBId)
    or not isPositiveInteger(actorCharId)
  then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end
  if not RPSTACK_FACTIONS_STATE.factions[factionAId]
    or not RPSTACK_FACTIONS_STATE.factions[factionBId]
  then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end
  if factionAId == factionBId or not VALID_STATUS[status] then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end
  if not RPSTACK_FACTIONS_RANKS.hasPerm(
    factionAId,
    actorCharId,
    FACTION_PERMS.DECLARE
  ) then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end

  local storedAId, storedBId = canonicalPair(factionAId, factionBId)
  RPSTACK_FACTIONS_REPO.upsertRelationship(
    storedAId,
    storedBId,
    status,
    actorCharId,
    function()
      RPSTACK_FACTIONS_CACHE.setRelationship(factionAId, factionBId, status)
      RPSTACK_FACTIONS_AUDIT.log(
        factionAId,
        actorCharId,
        FACTION_AUDIT.RELATIONSHIP_CHANGED,
        { targetFactionId = factionBId, status = status }
      )
      RPSTACK_LOG.info("factions", "relationship changed", {
        factionA = factionAId,
        factionB = factionBId,
        status = status,
      })
      TriggerEvent(FACTION_EVENTS.RELATIONSHIP_CHANGED, {
        factionAId = factionAId,
        factionBId = factionBId,
        status = status,
      })
      cb({ ok = true })
    end
  )
end
