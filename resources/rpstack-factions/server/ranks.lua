-- Rank CRUD and permission resolution.

RPSTACK_FACTIONS_RANKS = {}

local PERMISSION_KEYS = {
  "can_recruit",
  "can_kick",
  "can_deposit",
  "can_withdraw",
  "can_promote",
  "can_disband",
  "can_declare",
}

local function isPositiveInteger(value)
  return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function isValidLevel(value)
  return type(value) == "number"
    and value >= 0
    and value <= 255
    and value == math.floor(value)
end

local function validatePermissionFields(payload)
  for key, value in pairs(payload) do
    if key ~= "name" and key ~= "level" then
      if not FACTION_PERMS_SET[key] or type(value) ~= "boolean" then
        return false
      end
    end
  end
  return true
end

local function actorCanGrantPermissions(actorRank, permissions)
  for _, key in ipairs(PERMISSION_KEYS) do
    if permissions[key] == true and actorRank[key] ~= true then
      return false
    end
  end
  return true
end

local function buildPermissions(payload, existing)
  local permissions = {}
  for _, key in ipairs(PERMISSION_KEYS) do
    if payload[key] ~= nil then
      permissions[key] = payload[key]
    elseif existing and existing[key] ~= nil then
      permissions[key] = existing[key]
    else
      permissions[key] = key == "can_deposit"
    end
  end
  return permissions
end

function RPSTACK_FACTIONS_RANKS.getRanks(factionId)
  local rankMap = RPSTACK_FACTIONS_STATE.ranks[factionId]
  if not rankMap then return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND } end
  local list = {}
  for _, rank in pairs(rankMap) do list[#list + 1] = rank end
  table.sort(list, function(a, b) return a.level < b.level end)
  return { ok = true, ranks = list }
end

function RPSTACK_FACTIONS_RANKS.getRank(factionId, rankId)
  local rankMap = RPSTACK_FACTIONS_STATE.ranks[factionId]
  return rankMap and rankMap[rankId] or nil
end

function RPSTACK_FACTIONS_RANKS.getTopRankId(factionId)
  local levelMap = RPSTACK_FACTIONS_STATE.rank_by_level[factionId]
  if not levelMap then return nil end
  local topLevel, topId = -1, nil
  for level, rankId in pairs(levelMap) do
    if level > topLevel then
      topLevel = level
      topId = rankId
    end
  end
  return topId
end

function RPSTACK_FACTIONS_RANKS.hasPerm(factionId, characterId, permission)
  if not FACTION_PERMS_SET[permission] then return false end
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  local rankId = charFactions and charFactions[factionId]
  local rankMap = rankId and RPSTACK_FACTIONS_STATE.ranks[factionId]
  local rank = rankMap and rankMap[rankId]
  return rank and rank[permission] == true or false
end

function RPSTACK_FACTIONS_RANKS.getRankLevel(factionId, characterId)
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  local rankId = charFactions and charFactions[factionId]
  local rankMap = rankId and RPSTACK_FACTIONS_STATE.ranks[factionId]
  local rank = rankMap and rankMap[rankId]
  return rank and rank.level or nil
end

function RPSTACK_FACTIONS_RANKS.createRank(factionId, payload, actorCharId, cb)
  if type(cb) ~= "function" then return end
  if not isPositiveInteger(factionId)
    or not isPositiveInteger(actorCharId)
    or type(payload) ~= "table"
  then
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
  if type(payload.name) ~= "string"
    or #payload.name < 1
    or #payload.name > 32
    or not isValidLevel(payload.level)
    or not validatePermissionFields(payload)
  then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end

  local actorRank = RPSTACK_FACTIONS_MEMBERSHIP.getCharacterFactionRank(
    factionId,
    actorCharId
  ).rank
  if not actorRank or payload.level >= actorRank.level then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end

  local permissions = buildPermissions(payload)
  if not actorCanGrantPermissions(actorRank, permissions) then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end
  if RPSTACK_FACTIONS_STATE.rank_by_level[factionId][payload.level] then
    cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT })
    return
  end

  RPSTACK_FACTIONS_REPO.insertRank(
    factionId,
    payload.name,
    payload.level,
    permissions,
    function(rankId)
      if not rankId then
        cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
        return
      end

      local rank = {
        id = rankId,
        faction_id = factionId,
        name = payload.name,
        level = payload.level,
      }
      for key, value in pairs(permissions) do rank[key] = value end

      RPSTACK_FACTIONS_CACHE.addRank(factionId, rank)
      RPSTACK_FACTIONS_AUDIT.log(
        factionId,
        actorCharId,
        FACTION_AUDIT.RANK_CREATED,
        { rankId = rankId, name = rank.name }
      )
      cb({ ok = true, rank = rank })
    end
  )
end

function RPSTACK_FACTIONS_RANKS.updateRank(
  factionId,
  rankId,
  payload,
  actorCharId,
  cb
)
  if type(cb) ~= "function" then return end
  if not isPositiveInteger(factionId)
    or not isPositiveInteger(rankId)
    or not isPositiveInteger(actorCharId)
    or type(payload) ~= "table"
    or not validatePermissionFields(payload)
  then
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

  local existing = RPSTACK_FACTIONS_RANKS.getRank(factionId, rankId)
  if not existing then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end

  local name = payload.name == nil and existing.name or payload.name
  local level = payload.level == nil and existing.level or payload.level
  if type(name) ~= "string"
    or #name < 1
    or #name > 32
    or not isValidLevel(level)
  then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end

  local actorRank = RPSTACK_FACTIONS_MEMBERSHIP.getCharacterFactionRank(
    factionId,
    actorCharId
  ).rank
  if not actorRank then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end
  if rankId == actorRank.id
    or existing.level >= actorRank.level
    or level >= actorRank.level
  then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end

  local permissions = buildPermissions(payload, existing)
  if not actorCanGrantPermissions(actorRank, permissions) then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end

  local levelOwner = RPSTACK_FACTIONS_STATE.rank_by_level[factionId][level]
  if levelOwner and levelOwner ~= rankId then
    cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT })
    return
  end

  RPSTACK_FACTIONS_REPO.updateRank(
    rankId,
    name,
    level,
    permissions,
    function(affected)
      if affected == 0
        and (name ~= existing.name or level ~= existing.level)
      then
        cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
        return
      end

      local updated = {
        id = rankId,
        faction_id = factionId,
        name = name,
        level = level,
      }
      for key, value in pairs(permissions) do updated[key] = value end

      RPSTACK_FACTIONS_CACHE.updateRank(factionId, updated)
      RPSTACK_FACTIONS_AUDIT.log(
        factionId,
        actorCharId,
        FACTION_AUDIT.RANK_UPDATED,
        { rankId = rankId }
      )
      cb({ ok = true })
    end
  )
end

function RPSTACK_FACTIONS_RANKS.seedDefaults(factionId, factionType, cb)
  local templates = RPSTACK_FACTIONS_CONFIG.default_ranks[factionType]
  if not templates or #templates == 0 then
    cb(nil, false)
    return
  end

  local topRankId = nil
  local topLevel = -1
  local remaining = #templates
  local failed = false

  for _, template in ipairs(templates) do
    local rankTemplate = template
    RPSTACK_FACTIONS_REPO.insertRank(
      factionId,
      rankTemplate.name,
      rankTemplate.level,
      rankTemplate,
      function(rankId)
        if not rankId then
          failed = true
        else
          local rank = {
            id = rankId,
            faction_id = factionId,
            name = rankTemplate.name,
            level = rankTemplate.level,
          }
          local permissions = buildPermissions(rankTemplate)
          for key, value in pairs(permissions) do rank[key] = value end
          RPSTACK_FACTIONS_CACHE.addRank(factionId, rank)

          if rankTemplate.level > topLevel then
            topLevel = rankTemplate.level
            topRankId = rankId
          end
        end

        remaining = remaining - 1
        if remaining == 0 then cb(topRankId, not failed and topRankId ~= nil) end
      end
    )
  end
end
