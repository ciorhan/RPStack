-- rpstack-factions/server/ranks.lua
-- Rank CRUD and permission resolution.
-- Reads are O(1) from cache. Writes are async.

RPSTACK_FACTIONS_RANKS = {}

-- ── Reads (pure cache) ────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_RANKS.getRanks(factionId)
  local rankMap = RPSTACK_FACTIONS_STATE.ranks[factionId]
  if not rankMap then return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND } end
  local list = {}
  for _, rank in pairs(rankMap) do table.insert(list, rank) end
  table.sort(list, function(a, b) return a.level < b.level end)
  return { ok = true, ranks = list }
end

function RPSTACK_FACTIONS_RANKS.getRank(factionId, rankId)
  local rankMap = RPSTACK_FACTIONS_STATE.ranks[factionId]
  if not rankMap then return nil end
  return rankMap[rankId]
end

function RPSTACK_FACTIONS_RANKS.getTopRankId(factionId)
  local levelMap = RPSTACK_FACTIONS_STATE.rank_by_level[factionId]
  if not levelMap then return nil end
  local topLevel, topId = -1, nil
  for level, rankId in pairs(levelMap) do
    if level > topLevel then topLevel = level; topId = rankId end
  end
  return topId
end

-- O(1) permission check — hot path
function RPSTACK_FACTIONS_RANKS.hasPerm(factionId, characterId, perm)
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  if not charFactions then return false end
  local rankId = charFactions[factionId]
  if not rankId then return false end
  local rankMap = RPSTACK_FACTIONS_STATE.ranks[factionId]
  if not rankMap then return false end
  local rank = rankMap[rankId]
  return rank and rank[perm] == true
end

function RPSTACK_FACTIONS_RANKS.getRankLevel(factionId, characterId)
  local charFactions = RPSTACK_FACTIONS_STATE.char_factions[characterId]
  if not charFactions then return nil end
  local rankId = charFactions[factionId]
  if not rankId then return nil end
  local rankMap = RPSTACK_FACTIONS_STATE.ranks[factionId]
  if not rankMap then return nil end
  local rank = rankMap[rankId]
  return rank and rank.level or nil
end

-- ── Writes (async) ────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_RANKS.createRank(factionId, payload, actorCharId, cb)
  if not RPSTACK_FACTIONS_RANKS.hasPerm(factionId, actorCharId, FACTION_PERMS.PROMOTE) then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
  end
  if type(payload.name) ~= "string" or #payload.name < 1 or #payload.name > 32 then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end
  if type(payload.level) ~= "number" then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end

  local perms = {
    can_recruit  = payload.can_recruit  == true,
    can_kick     = payload.can_kick     == true,
    can_deposit  = payload.can_deposit  ~= false,
    can_withdraw = payload.can_withdraw == true,
    can_promote  = payload.can_promote  == true,
    can_disband  = payload.can_disband  == true,
    can_declare  = payload.can_declare  == true,
  }

  RPSTACK_FACTIONS_REPO.insertRank(factionId, payload.name, payload.level, perms, function(rankId)
    if not rankId then return cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL }) end

    local rank = { id = rankId, faction_id = factionId, name = payload.name, level = payload.level }
    for k, v in pairs(perms) do rank[k] = v end

    RPSTACK_FACTIONS_CACHE.addRank(factionId, rank)
    RPSTACK_FACTIONS_AUDIT.log(factionId, actorCharId, FACTION_AUDIT.RANK_CREATED, { rankId = rankId, name = rank.name })
    cb({ ok = true, rank = rank })
  end)
end

function RPSTACK_FACTIONS_RANKS.updateRank(factionId, rankId, payload, actorCharId, cb)
  if not RPSTACK_FACTIONS_RANKS.hasPerm(factionId, actorCharId, FACTION_PERMS.PROMOTE) then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
  end
  local existing = RPSTACK_FACTIONS_RANKS.getRank(factionId, rankId)
  if not existing then return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND }) end

  local name  = payload.name  or existing.name
  local level = payload.level or existing.level
  local perms = {
    can_recruit  = payload.can_recruit  ~= nil and payload.can_recruit  or existing.can_recruit,
    can_kick     = payload.can_kick     ~= nil and payload.can_kick     or existing.can_kick,
    can_deposit  = payload.can_deposit  ~= nil and payload.can_deposit  or existing.can_deposit,
    can_withdraw = payload.can_withdraw ~= nil and payload.can_withdraw or existing.can_withdraw,
    can_promote  = payload.can_promote  ~= nil and payload.can_promote  or existing.can_promote,
    can_disband  = payload.can_disband  ~= nil and payload.can_disband  or existing.can_disband,
    can_declare  = payload.can_declare  ~= nil and payload.can_declare  or existing.can_declare,
  }

  RPSTACK_FACTIONS_REPO.updateRank(rankId, name, level, perms, function()
    local updated = { id = rankId, faction_id = factionId, name = name, level = level }
    for k, v in pairs(perms) do updated[k] = v end
    RPSTACK_FACTIONS_CACHE.updateRank(factionId, updated)
    RPSTACK_FACTIONS_AUDIT.log(factionId, actorCharId, FACTION_AUDIT.RANK_UPDATED, { rankId = rankId })
    cb({ ok = true })
  end)
end

-- ── Seed defaults on faction creation (async, returns topRankId via cb) ───────

function RPSTACK_FACTIONS_RANKS.seedDefaults(factionId, factionType, cb)
  local templates = RPSTACK_FACTIONS_CONFIG.default_ranks[factionType]
  if not templates then
    RPSTACK_LOG.warn("factions", "no default ranks for type", { type = factionType })
    return cb(nil)
  end

  local topRankId = nil
  local topLevel  = -1
  local remaining = #templates

  if remaining == 0 then return cb(nil) end

  for _, template in ipairs(templates) do
    local t = template
    RPSTACK_FACTIONS_REPO.insertRank(factionId, t.name, t.level, t, function(rankId)
      if rankId then
        local rank = {
          id           = rankId,
          faction_id   = factionId,
          name         = t.name,
          level        = t.level,
          can_recruit  = t.can_recruit  == true,
          can_kick     = t.can_kick     == true,
          can_deposit  = t.can_deposit  ~= false,
          can_withdraw = t.can_withdraw == true,
          can_promote  = t.can_promote  == true,
          can_disband  = t.can_disband  == true,
          can_declare  = t.can_declare  == true,
        }
        RPSTACK_FACTIONS_CACHE.addRank(factionId, rank)
        if t.level > topLevel then
          topLevel  = t.level
          topRankId = rankId
        end
      end
      remaining = remaining - 1
      if remaining == 0 then cb(topRankId) end
    end)
  end
end