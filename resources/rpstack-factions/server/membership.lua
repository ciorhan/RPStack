-- rpstack-factions/server/membership.lua
-- All membership operations. Reads are O(1) from cache. Writes are async.

RPSTACK_FACTIONS_MEMBERSHIP = {}

-- ── Reads (O(1) cache) ────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_MEMBERSHIP.isMember(factionId, characterId)
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  if not charFactions then return { ok = true, member = false } end
  return { ok = true, member = charFactions[factionId] ~= nil }
end

function RPSTACK_FACTIONS_MEMBERSHIP.getCharacterFactions(characterId)
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  if not charFactions then return { ok = true, factions = {} } end
  local list = {}
  for factionId, rankId in pairs(charFactions) do
    local faction = RPSTACK_FACTIONS_STATE.factions[factionId]
    local rank    = RPSTACK_FACTIONS_STATE.ranks[factionId] and RPSTACK_FACTIONS_STATE.ranks[factionId][rankId]
    if faction then table.insert(list, { faction = faction, rankId = rankId, rank = rank }) end
  end
  return { ok = true, factions = list }
end

function RPSTACK_FACTIONS_MEMBERSHIP.getFactionMembers(factionId)
  local memberMap = RPSTACK_FACTIONS_STATE.members[factionId]
  if not memberMap then return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND } end
  local list = {}
  for charId, rankId in pairs(memberMap) do
    table.insert(list, { characterId = charId, rankId = rankId })
  end
  return { ok = true, members = list }
end

function RPSTACK_FACTIONS_MEMBERSHIP.getOnlineRoster(factionId)
  local roster = RPSTACK_FACTIONS_STATE.online_roster[factionId]
  if not roster then return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND } end
  local memberMap = RPSTACK_FACTIONS_STATE.members[factionId] or {}
  local list = {}
  for charId in pairs(roster) do
    table.insert(list, { characterId = charId, rankId = memberMap[charId] })
  end
  return { ok = true, roster = list }
end

function RPSTACK_FACTIONS_MEMBERSHIP.getCharacterFactionRank(factionId, characterId)
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  if not charFactions then return { ok = true, rank = nil } end
  local rankId = charFactions[factionId]
  if not rankId then return { ok = true, rank = nil } end
  local rankMap = RPSTACK_FACTIONS_STATE.ranks[factionId]
  return { ok = true, rank = rankMap and rankMap[rankId] or nil }
end

-- ── Writes (async) ────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_MEMBERSHIP.joinFaction(factionId, characterId, rankId, actorCharId, cb)
  if not RPSTACK_FACTIONS_STATE.factions[factionId] then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
  end
  if not RPSTACK_FACTIONS_RANKS.hasPerm(factionId, actorCharId, FACTION_PERMS.RECRUIT) then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
  end

  local actorLevel = RPSTACK_FACTIONS_RANKS.getRankLevel(factionId, actorCharId)
  local targetRank = RPSTACK_FACTIONS_STATE.ranks[factionId] and RPSTACK_FACTIONS_STATE.ranks[factionId][rankId]
  if not targetRank then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
  if actorLevel and targetRank.level >= actorLevel then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
  end

  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId] or {}
  if charFactions[factionId] then return cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT }) end

  local factionCount = 0
  for _ in pairs(charFactions) do factionCount = factionCount + 1 end
  if factionCount >= RPSTACK_FACTIONS_CONFIG.max_factions_per_character then
    return cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT })
  end

  RPSTACK_FACTIONS_REPO.insertMember(factionId, characterId, rankId, function(insertId)
    if not insertId then return cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL }) end
    RPSTACK_FACTIONS_CACHE.addMember(factionId, characterId, rankId)
    RPSTACK_FACTIONS_AUDIT.log(factionId, actorCharId, FACTION_AUDIT.MEMBER_JOINED, { characterId = characterId, rankId = rankId })
    RPSTACK_LOG.info("factions", "member joined", { factionId = factionId, characterId = characterId })
    TriggerEvent(FACTION_EVENTS.MEMBER_JOINED, { factionId = factionId, characterId = characterId, rankId = rankId })
    cb({ ok = true })
  end)
end

function RPSTACK_FACTIONS_MEMBERSHIP.leaveFaction(factionId, characterId, cb)
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  if not charFactions or not charFactions[factionId] then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
  end
  local memberMap = RPSTACK_FACTIONS_STATE.members[factionId] or {}
  local memberCount = 0
  for _ in pairs(memberMap) do memberCount = memberCount + 1 end
  if memberCount == 1 then return cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT }) end

  RPSTACK_FACTIONS_REPO.deleteMember(factionId, characterId, function()
    RPSTACK_FACTIONS_CACHE.removeMember(factionId, characterId)
    RPSTACK_FACTIONS_AUDIT.log(factionId, characterId, FACTION_AUDIT.MEMBER_LEFT, {})
    TriggerEvent(FACTION_EVENTS.MEMBER_LEFT, { factionId = factionId, characterId = characterId })
    cb({ ok = true })
  end)
end

function RPSTACK_FACTIONS_MEMBERSHIP.kickMember(factionId, characterId, actorCharId, cb)
  if not RPSTACK_FACTIONS_RANKS.hasPerm(factionId, actorCharId, FACTION_PERMS.KICK) then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
  end
  local actorLevel  = RPSTACK_FACTIONS_RANKS.getRankLevel(factionId, actorCharId)
  local targetLevel = RPSTACK_FACTIONS_RANKS.getRankLevel(factionId, characterId)
  if targetLevel == nil then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end
  if actorLevel and targetLevel >= actorLevel then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
  end

  RPSTACK_FACTIONS_REPO.deleteMember(factionId, characterId, function()
    RPSTACK_FACTIONS_CACHE.removeMember(factionId, characterId)
    RPSTACK_FACTIONS_AUDIT.log(factionId, actorCharId, FACTION_AUDIT.MEMBER_KICKED, { characterId = characterId })
    TriggerEvent(FACTION_EVENTS.MEMBER_KICKED, { factionId = factionId, characterId = characterId, byCharId = actorCharId })
    cb({ ok = true })
  end)
end

function RPSTACK_FACTIONS_MEMBERSHIP.setMemberRank(factionId, characterId, rankId, actorCharId, cb)
  if not RPSTACK_FACTIONS_RANKS.hasPerm(factionId, actorCharId, FACTION_PERMS.PROMOTE) then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
  end
  local targetRank = RPSTACK_FACTIONS_STATE.ranks[factionId] and RPSTACK_FACTIONS_STATE.ranks[factionId][rankId]
  if not targetRank then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end

  local actorLevel = RPSTACK_FACTIONS_RANKS.getRankLevel(factionId, actorCharId)
  if actorLevel and targetRank.level >= actorLevel then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
  end

  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  if not charFactions or not charFactions[factionId] then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
  end
  local oldRankId = charFactions[factionId]

  RPSTACK_FACTIONS_REPO.updateMemberRank(factionId, characterId, rankId, function()
    RPSTACK_FACTIONS_CACHE.updateMemberRank(factionId, characterId, rankId)
    RPSTACK_FACTIONS_AUDIT.log(factionId, actorCharId, FACTION_AUDIT.RANK_CHANGED, {
      characterId = characterId, oldRankId = oldRankId, newRankId = rankId
    })
    TriggerEvent(FACTION_EVENTS.RANK_CHANGED, {
      factionId = factionId, characterId = characterId, oldRankId = oldRankId, newRankId = rankId
    })
    cb({ ok = true })
  end)
end

-- ── Online roster ─────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_MEMBERSHIP.onCharacterLoaded(characterId)
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  if not charFactions then return end
  for factionId in pairs(charFactions) do
    RPSTACK_FACTIONS_CACHE.setOnline(factionId, characterId)
  end
end

function RPSTACK_FACTIONS_MEMBERSHIP.onCharacterUnloaded(characterId)
  RPSTACK_FACTIONS_CACHE.setOffline(characterId)
end