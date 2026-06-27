-- rpstack-factions/server/exports.lua
-- All public exports. Thin wrappers only — no logic here.
--
-- SYNC exports (pure cache reads — safe to call on every action):
--   getFaction, getFactionByTag, listFactions
--   isMember, getCharacterFactionRank, characterHasFactionPerm
--   getCharacterFactions, getFactionMembers, getOnlineRoster, getRanks
--   getRelationship, getFactionAllies, getFactionHostiles
--
-- ASYNC exports (DB writes or economy calls — require callback as last arg):
--   createFaction, disbandFaction
--   joinFaction, leaveFaction, kickMember, setMemberRank
--   createRank, updateRank
--   setRelationship
--   depositToTreasury, withdrawFromTreasury, getTreasuryBalance, getTreasuryLedger

local function localCallback(callback)
  if callback == nil then return nil end
  return function(result)
    callback(result)
  end
end

-- ── Faction CRUD ──────────────────────────────────────────────────────────────

exports('createFaction', function(payload, cb)
  RPSTACK_FACTIONS_FACTION.createFaction(payload, localCallback(cb))
end)

exports('getFaction', function(factionId)
  return RPSTACK_FACTIONS_FACTION.getFaction(factionId)
end)

exports('getFactionByTag', function(tag)
  return RPSTACK_FACTIONS_FACTION.getFactionByTag(tag)
end)

exports('listFactions', function()
  return RPSTACK_FACTIONS_FACTION.listFactions()
end)

exports('disbandFaction', function(factionId, actorCharId, cb)
  RPSTACK_FACTIONS_FACTION.disbandFaction(factionId, actorCharId, localCallback(cb))
end)

-- ── Membership ────────────────────────────────────────────────────────────────

exports('joinFaction', function(factionId, characterId, rankId, actorCharId, cb)
  RPSTACK_FACTIONS_MEMBERSHIP.joinFaction(factionId, characterId, rankId, actorCharId, localCallback(cb))
end)

exports('leaveFaction', function(factionId, characterId, cb)
  RPSTACK_FACTIONS_MEMBERSHIP.leaveFaction(factionId, characterId, localCallback(cb))
end)

exports('kickMember', function(factionId, characterId, actorCharId, cb)
  RPSTACK_FACTIONS_MEMBERSHIP.kickMember(factionId, characterId, actorCharId, localCallback(cb))
end)

exports('setMemberRank', function(factionId, characterId, rankId, actorCharId, cb)
  RPSTACK_FACTIONS_MEMBERSHIP.setMemberRank(factionId, characterId, rankId, actorCharId, localCallback(cb))
end)

exports('getCharacterFactions', function(characterId)
  return RPSTACK_FACTIONS_MEMBERSHIP.getCharacterFactions(characterId)
end)

exports('getFactionMembers', function(factionId)
  return RPSTACK_FACTIONS_MEMBERSHIP.getFactionMembers(factionId)
end)

exports('getOnlineRoster', function(factionId)
  return RPSTACK_FACTIONS_MEMBERSHIP.getOnlineRoster(factionId)
end)

-- ── Permission checks (sync — O(1) cache reads) ───────────────────────────────

exports('characterHasFactionPerm', function(factionId, characterId, perm)
  return { ok = true, allowed = RPSTACK_FACTIONS_RANKS.hasPerm(factionId, characterId, perm) }
end)

exports('getCharacterFactionRank', function(factionId, characterId)
  return RPSTACK_FACTIONS_MEMBERSHIP.getCharacterFactionRank(factionId, characterId)
end)

exports('isMember', function(factionId, characterId)
  return RPSTACK_FACTIONS_MEMBERSHIP.isMember(factionId, characterId)
end)

-- ── Ranks ─────────────────────────────────────────────────────────────────────

exports('createRank', function(factionId, payload, actorCharId, cb)
  RPSTACK_FACTIONS_RANKS.createRank(factionId, payload, actorCharId, localCallback(cb))
end)

exports('updateRank', function(factionId, rankId, payload, actorCharId, cb)
  RPSTACK_FACTIONS_RANKS.updateRank(factionId, rankId, payload, actorCharId, localCallback(cb))
end)

exports('getRanks', function(factionId)
  return RPSTACK_FACTIONS_RANKS.getRanks(factionId)
end)

-- ── Relationships ─────────────────────────────────────────────────────────────

exports('setRelationship', function(factionAId, factionBId, status, actorCharId, cb)
  RPSTACK_FACTIONS_RELATIONSHIPS.setRelationship(factionAId, factionBId, status, actorCharId, localCallback(cb))
end)

exports('getRelationship', function(factionAId, factionBId)
  return RPSTACK_FACTIONS_RELATIONSHIPS.getRelationship(factionAId, factionBId)
end)

exports('getFactionAllies', function(factionId)
  return RPSTACK_FACTIONS_RELATIONSHIPS.getFactionAllies(factionId)
end)

exports('getFactionHostiles', function(factionId)
  return RPSTACK_FACTIONS_RELATIONSHIPS.getFactionHostiles(factionId)
end)

-- ── Treasury (async) ──────────────────────────────────────────────────────────

exports('depositToTreasury', function(factionId, characterId, amount, note, cb)
  RPSTACK_FACTIONS_TREASURY.deposit(factionId, characterId, amount, note, localCallback(cb))
end)

exports('withdrawFromTreasury', function(factionId, characterId, amount, note, cb)
  RPSTACK_FACTIONS_TREASURY.withdraw(factionId, characterId, amount, note, localCallback(cb))
end)

exports('getTreasuryBalance', function(factionId, cb)
  RPSTACK_FACTIONS_TREASURY.getBalance(factionId, localCallback(cb))
end)

exports('getTreasuryLedger', function(factionId, limit, cb)
  RPSTACK_FACTIONS_TREASURY.getLedger(factionId, limit, localCallback(cb))
end)
