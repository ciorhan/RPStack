-- Faction membership operations.

RPSTACK_FACTIONS_MEMBERSHIP = {}

local function isPositiveInteger(value)
  return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function validWriteArgs(factionId, characterId, cb)
  return type(cb) == "function"
    and isPositiveInteger(factionId)
    and isPositiveInteger(characterId)
end

function RPSTACK_FACTIONS_MEMBERSHIP.isMember(factionId, characterId)
  if not isPositiveInteger(factionId) or not isPositiveInteger(characterId) then
    return { ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }
  end
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  return {
    ok = true,
    member = charFactions ~= nil and charFactions[factionId] ~= nil,
  }
end

function RPSTACK_FACTIONS_MEMBERSHIP.getCharacterFactions(characterId)
  if not isPositiveInteger(characterId) then
    return { ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }
  end
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId] or {}
  local list = {}
  for factionId, rankId in pairs(charFactions) do
    local faction = RPSTACK_FACTIONS_STATE.factions[factionId]
    local rankMap = RPSTACK_FACTIONS_STATE.ranks[factionId]
    if faction then
      list[#list + 1] = {
        faction = faction,
        rankId = rankId,
        rank = rankMap and rankMap[rankId] or nil,
      }
    end
  end
  return { ok = true, factions = list }
end

function RPSTACK_FACTIONS_MEMBERSHIP.getFactionMembers(factionId)
  if not isPositiveInteger(factionId) then
    return { ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }
  end
  local memberMap = RPSTACK_FACTIONS_STATE.members[factionId]
  if not memberMap then return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND } end
  local list = {}
  for characterId, rankId in pairs(memberMap) do
    list[#list + 1] = { characterId = characterId, rankId = rankId }
  end
  return { ok = true, members = list }
end

function RPSTACK_FACTIONS_MEMBERSHIP.getOnlineRoster(factionId)
  if not isPositiveInteger(factionId) then
    return { ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }
  end
  local roster = RPSTACK_FACTIONS_STATE.online_roster[factionId]
  if not roster then return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND } end
  local memberMap = RPSTACK_FACTIONS_STATE.members[factionId] or {}
  local list = {}
  for characterId in pairs(roster) do
    list[#list + 1] = {
      characterId = characterId,
      rankId = memberMap[characterId],
    }
  end
  return { ok = true, roster = list }
end

function RPSTACK_FACTIONS_MEMBERSHIP.getCharacterFactionRank(factionId, characterId)
  if not isPositiveInteger(factionId) or not isPositiveInteger(characterId) then
    return { ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }
  end
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  local rankId = charFactions and charFactions[factionId]
  local rankMap = rankId and RPSTACK_FACTIONS_STATE.ranks[factionId]
  return { ok = true, rank = rankMap and rankMap[rankId] or nil }
end

function RPSTACK_FACTIONS_MEMBERSHIP.joinFaction(
  factionId,
  characterId,
  rankId,
  actorCharId,
  cb
)
  if not validWriteArgs(factionId, characterId, cb)
    or not isPositiveInteger(rankId)
    or not isPositiveInteger(actorCharId)
  then
    if type(cb) == "function" then
      cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    end
    return
  end
  if not RPSTACK_FACTIONS_STATE.factions[factionId] then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end
  if not RPSTACK_FACTIONS_RANKS.hasPerm(
    factionId,
    actorCharId,
    FACTION_PERMS.RECRUIT
  ) then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end

  local actorLevel = RPSTACK_FACTIONS_RANKS.getRankLevel(factionId, actorCharId)
  local targetRank = RPSTACK_FACTIONS_RANKS.getRank(factionId, rankId)
  if not targetRank then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end
  if not actorLevel or targetRank.level >= actorLevel then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end

  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId] or {}
  if charFactions[factionId] then
    cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT })
    return
  end

  local factionCount = 0
  for _ in pairs(charFactions) do factionCount = factionCount + 1 end
  if factionCount >= RPSTACK_FACTIONS_CONFIG.max_factions_per_character then
    cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT })
    return
  end

  RPSTACK_FACTIONS_REPO.insertMember(
    factionId,
    characterId,
    rankId,
    function(insertId)
      if not insertId then
        cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
        return
      end
      RPSTACK_FACTIONS_CACHE.addMember(factionId, characterId, rankId)
      RPSTACK_FACTIONS_AUDIT.log(
        factionId,
        actorCharId,
        FACTION_AUDIT.MEMBER_JOINED,
        { characterId = characterId, rankId = rankId }
      )
      TriggerEvent(FACTION_EVENTS.MEMBER_JOINED, {
        factionId = factionId,
        characterId = characterId,
        rankId = rankId,
      })
      cb({ ok = true })
    end
  )
end

local function isLastTopRankMember(factionId, characterId)
  local topRankId = RPSTACK_FACTIONS_RANKS.getTopRankId(factionId)
  local memberMap = RPSTACK_FACTIONS_STATE.members[factionId] or {}
  if memberMap[characterId] ~= topRankId then return false end

  for otherCharacterId, rankId in pairs(memberMap) do
    if otherCharacterId ~= characterId and rankId == topRankId then
      return false
    end
  end
  return true
end

function RPSTACK_FACTIONS_MEMBERSHIP.leaveFaction(factionId, characterId, cb)
  if not validWriteArgs(factionId, characterId, cb) then
    if type(cb) == "function" then
      cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    end
    return
  end
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  if not charFactions or not charFactions[factionId] then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end
  if isLastTopRankMember(factionId, characterId) then
    cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT })
    return
  end

  RPSTACK_FACTIONS_REPO.deleteMember(factionId, characterId, function(affected)
    if affected ~= 1 then
      cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
      return
    end
    RPSTACK_FACTIONS_CACHE.removeMember(factionId, characterId)
    RPSTACK_FACTIONS_AUDIT.log(
      factionId,
      characterId,
      FACTION_AUDIT.MEMBER_LEFT,
      {}
    )
    TriggerEvent(FACTION_EVENTS.MEMBER_LEFT, {
      factionId = factionId,
      characterId = characterId,
    })
    cb({ ok = true })
  end)
end

function RPSTACK_FACTIONS_MEMBERSHIP.kickMember(
  factionId,
  characterId,
  actorCharId,
  cb
)
  if not validWriteArgs(factionId, characterId, cb)
    or not isPositiveInteger(actorCharId)
  then
    if type(cb) == "function" then
      cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    end
    return
  end
  if characterId == actorCharId then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end
  if not RPSTACK_FACTIONS_RANKS.hasPerm(
    factionId,
    actorCharId,
    FACTION_PERMS.KICK
  ) then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end

  local actorLevel = RPSTACK_FACTIONS_RANKS.getRankLevel(factionId, actorCharId)
  local targetLevel = RPSTACK_FACTIONS_RANKS.getRankLevel(factionId, characterId)
  if not targetLevel then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end
  if not actorLevel or targetLevel >= actorLevel then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end

  RPSTACK_FACTIONS_REPO.deleteMember(factionId, characterId, function(affected)
    if affected ~= 1 then
      cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
      return
    end
    RPSTACK_FACTIONS_CACHE.removeMember(factionId, characterId)
    RPSTACK_FACTIONS_AUDIT.log(
      factionId,
      actorCharId,
      FACTION_AUDIT.MEMBER_KICKED,
      { characterId = characterId }
    )
    TriggerEvent(FACTION_EVENTS.MEMBER_KICKED, {
      factionId = factionId,
      characterId = characterId,
      byCharId = actorCharId,
    })
    cb({ ok = true })
  end)
end

function RPSTACK_FACTIONS_MEMBERSHIP.setMemberRank(
  factionId,
  characterId,
  rankId,
  actorCharId,
  cb
)
  if not validWriteArgs(factionId, characterId, cb)
    or not isPositiveInteger(rankId)
    or not isPositiveInteger(actorCharId)
  then
    if type(cb) == "function" then
      cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    end
    return
  end
  if characterId == actorCharId then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end
  if not RPSTACK_FACTIONS_RANKS.hasPerm(
    factionId,
    actorCharId,
    FACTION_PERMS.PROMOTE
  ) then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end

  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  local targetRank = RPSTACK_FACTIONS_RANKS.getRank(factionId, rankId)
  if not charFactions or not charFactions[factionId] or not targetRank then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end

  local actorLevel = RPSTACK_FACTIONS_RANKS.getRankLevel(factionId, actorCharId)
  local currentLevel = RPSTACK_FACTIONS_RANKS.getRankLevel(factionId, characterId)
  if not actorLevel
    or not currentLevel
    or currentLevel >= actorLevel
    or targetRank.level >= actorLevel
  then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end

  local oldRankId = charFactions[factionId]
  if oldRankId == rankId then
    cb({ ok = true })
    return
  end

  RPSTACK_FACTIONS_REPO.updateMemberRank(
    factionId,
    characterId,
    rankId,
    function(affected)
      if affected ~= 1 then
        cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
        return
      end
      RPSTACK_FACTIONS_CACHE.updateMemberRank(factionId, characterId, rankId)
      RPSTACK_FACTIONS_AUDIT.log(
        factionId,
        actorCharId,
        FACTION_AUDIT.RANK_CHANGED,
        {
          characterId = characterId,
          oldRankId = oldRankId,
          newRankId = rankId,
        }
      )
      TriggerEvent(FACTION_EVENTS.RANK_CHANGED, {
        factionId = factionId,
        characterId = characterId,
        oldRankId = oldRankId,
        newRankId = rankId,
      })
      cb({ ok = true })
    end
  )
end

function RPSTACK_FACTIONS_MEMBERSHIP.onCharacterLoaded(characterId)
  if not isPositiveInteger(characterId) then return end
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  if not charFactions then return end
  for factionId in pairs(charFactions) do
    RPSTACK_FACTIONS_CACHE.setOnline(factionId, characterId)
  end
end

function RPSTACK_FACTIONS_MEMBERSHIP.onCharacterUnloaded(characterId)
  if not isPositiveInteger(characterId) then return end
  RPSTACK_FACTIONS_CACHE.setOffline(characterId)
end
