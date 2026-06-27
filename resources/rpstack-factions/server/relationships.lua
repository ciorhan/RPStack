-- rpstack-factions/server/relationships.lua
-- Faction-to-faction relationship management.
-- Reads are O(1) from cache (called frequently by law/supply/combat systems).

RPSTACK_FACTIONS_RELATIONSHIPS = {}

local VALID_STATUS = {
  [FACTION_RELATIONSHIP.ALLY]    = true,
  [FACTION_RELATIONSHIP.NEUTRAL] = true,
  [FACTION_RELATIONSHIP.HOSTILE] = true,
}

-- ── Reads (O(1) cache) ────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_RELATIONSHIPS.getRelationship(factionAId, factionBId)
  if factionAId == factionBId then
    -- A faction's relationship with itself is always ally
    return { ok = true, status = FACTION_RELATIONSHIP.ALLY }
  end

  local relMap = RPSTACK_FACTIONS_STATE.relationships[factionAId]
  if not relMap then
    return { ok = true, status = FACTION_RELATIONSHIP.NEUTRAL }
  end

  local status = relMap[factionBId] or FACTION_RELATIONSHIP.NEUTRAL
  return { ok = true, status = status }
end

function RPSTACK_FACTIONS_RELATIONSHIPS.getFactionAllies(factionId)
  return RPSTACK_FACTIONS_RELATIONSHIPS._getByStatus(factionId, FACTION_RELATIONSHIP.ALLY)
end

function RPSTACK_FACTIONS_RELATIONSHIPS.getFactionHostiles(factionId)
  return RPSTACK_FACTIONS_RELATIONSHIPS._getByStatus(factionId, FACTION_RELATIONSHIP.HOSTILE)
end

function RPSTACK_FACTIONS_RELATIONSHIPS._getByStatus(factionId, status)
  local relMap = RPSTACK_FACTIONS_STATE.relationships[factionId]
  if not relMap then return { ok = true, factions = {} } end

  local list = {}
  for otherFactionId, s in pairs(relMap) do
    if s == status then
      local faction = RPSTACK_FACTIONS_STATE.factions[otherFactionId]
      if faction then table.insert(list, faction) end
    end
  end
  return { ok = true, factions = list }
end

-- ── Write ─────────────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_RELATIONSHIPS.setRelationship(factionAId, factionBId, status, actorCharId)
  -- Both factions must exist
  if not RPSTACK_FACTIONS_STATE.factions[factionAId] then
    return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND }
  end
  if not RPSTACK_FACTIONS_STATE.factions[factionBId] then
    return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND }
  end
  if factionAId == factionBId then
    return { ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }
  end

  -- Validate status
  if not VALID_STATUS[status] then
    return { ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }
  end

  -- Actor must have can_declare in faction A
  if not RPSTACK_FACTIONS_RANKS.hasPerm(factionAId, actorCharId, FACTION_PERMS.DECLARE) then
    return { ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED }
  end

  -- Persist (upsert, both directions stored as one canonical row)
  RPSTACK_FACTIONS_REPO.upsertRelationship(factionAId, factionBId, status, actorCharId, function() end)

  -- Update cache both directions
  RPSTACK_FACTIONS_CACHE.setRelationship(factionAId, factionBId, status)

  RPSTACK_FACTIONS_AUDIT.log(factionAId, actorCharId, FACTION_AUDIT.RELATIONSHIP_CHANGED, {
    targetFactionId = factionBId, status = status
  })

  RPSTACK_LOG.info("factions", "relationship changed", {
    factionA = factionAId, factionB = factionBId, status = status
  })

  TriggerEvent(FACTION_EVENTS.RELATIONSHIP_CHANGED, {
    factionAId = factionAId,
    factionBId = factionBId,
    status     = status,
  })

  return { ok = true }
end