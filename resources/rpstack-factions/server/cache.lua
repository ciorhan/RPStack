-- rpstack-factions/server/cache.lua
-- Hydrates RPSTACK_FACTIONS_STATE from DB on startup via async waterfall.
-- Mutation helpers keep cache consistent after every write operation.

RPSTACK_FACTIONS_CACHE = {}

-- ── Startup hydration (async waterfall) ───────────────────────────────────────
-- Loads factions → ranks → members → relationships in sequence.
-- Calls cb() when complete.

function RPSTACK_FACTIONS_CACHE.hydrate(cb)
  local state = RPSTACK_FACTIONS_STATE

  -- Step 1: load factions
  RPSTACK_FACTIONS_REPO.loadAllFactions(function(factions)
    for _, row in ipairs(factions or {}) do
      state.factions[row.id] = {
        id          = row.id,
        name        = row.name,
        tag         = row.tag,
        type        = row.type,
        description = row.description,
        is_active   = row.is_active == 1,
        created_at  = row.created_at,
      }
      state.tags[string.upper(row.tag)] = row.id
      state.ranks[row.id]             = {}
      state.rank_by_level[row.id]     = {}
      state.members[row.id]           = {}
      state.online_roster[row.id]     = {}
      state.relationships[row.id]     = {}
    end

    -- Step 2: load ranks
    RPSTACK_FACTIONS_REPO.loadAllRanks(function(ranks)
      for _, row in ipairs(ranks or {}) do
        local fid = row.faction_id
        if state.ranks[fid] then
          local rank = RPSTACK_FACTIONS_CACHE._rowToRank(row)
          state.ranks[fid][row.id]            = rank
          state.rank_by_level[fid][row.level] = row.id
        end
      end

      -- Step 3: load members
      RPSTACK_FACTIONS_REPO.loadAllMembers(function(members)
        for _, row in ipairs(members or {}) do
          local fid = row.faction_id
          local cid = row.character_id
          if state.members[fid] then
            state.members[fid][cid] = row.rank_id
            if not state.char_factions[cid] then
              state.char_factions[cid] = {}
            end
            state.char_factions[cid][fid] = row.rank_id
          end
        end

        -- Step 4: load relationships
        RPSTACK_FACTIONS_REPO.loadAllRelationships(function(rels)
          for _, row in ipairs(rels or {}) do
            local a, b = row.faction_a_id, row.faction_b_id
            if state.relationships[a] then state.relationships[a][b] = row.status end
            if state.relationships[b] then state.relationships[b][a] = row.status end
          end

          state._ready = true

          RPSTACK_LOG.info("factions", "cache hydrated", {
            factions      = (function() local n=0 for _ in pairs(state.factions) do n=n+1 end return n end)(),
            ranks         = (function() local n=0 for _,t in pairs(state.ranks) do for _ in pairs(t) do n=n+1 end end return n end)(),
            members       = (function() local n=0 for _,t in pairs(state.members) do for _ in pairs(t) do n=n+1 end end return n end)(),
          })

          if cb then cb() end
        end)
      end)
    end)
  end)
end

-- ── Cache mutation helpers ────────────────────────────────────────────────────

function RPSTACK_FACTIONS_CACHE.addFaction(faction)
  local state = RPSTACK_FACTIONS_STATE
  state.factions[faction.id]      = faction
  state.tags[string.upper(faction.tag)] = faction.id
  state.ranks[faction.id]         = {}
  state.rank_by_level[faction.id] = {}
  state.members[faction.id]       = {}
  state.online_roster[faction.id] = {}
  state.relationships[faction.id] = {}
end

function RPSTACK_FACTIONS_CACHE.removeFaction(factionId)
  local state = RPSTACK_FACTIONS_STATE
  local faction = state.factions[factionId]
  if faction then state.tags[string.upper(faction.tag)] = nil end
  if state.members[factionId] then
    for charId in pairs(state.members[factionId]) do
      if state.char_factions[charId] then
        state.char_factions[charId][factionId] = nil
      end
    end
  end
  state.factions[factionId]      = nil
  state.ranks[factionId]         = nil
  state.rank_by_level[factionId] = nil
  state.members[factionId]       = nil
  state.online_roster[factionId] = nil
  state.relationships[factionId] = nil
end

function RPSTACK_FACTIONS_CACHE.addRank(factionId, rank)
  local state = RPSTACK_FACTIONS_STATE
  if not state.ranks[factionId] then return end
  state.ranks[factionId][rank.id]            = rank
  state.rank_by_level[factionId][rank.level] = rank.id
end

function RPSTACK_FACTIONS_CACHE.updateRank(factionId, rank)
  local state = RPSTACK_FACTIONS_STATE
  local existing = state.ranks[factionId] and state.ranks[factionId][rank.id]
  if existing
    and existing.level ~= rank.level
    and state.rank_by_level[factionId]
  then
    state.rank_by_level[factionId][existing.level] = nil
  end
  RPSTACK_FACTIONS_CACHE.addRank(factionId, rank)
end

function RPSTACK_FACTIONS_CACHE.addMember(factionId, characterId, rankId)
  local state = RPSTACK_FACTIONS_STATE
  if state.members[factionId] then
    state.members[factionId][characterId] = rankId
  end
  if not state.char_factions[characterId] then
    state.char_factions[characterId] = {}
  end
  state.char_factions[characterId][factionId] = rankId
end

function RPSTACK_FACTIONS_CACHE.removeMember(factionId, characterId)
  local state = RPSTACK_FACTIONS_STATE
  if state.members[factionId] then
    state.members[factionId][characterId] = nil
  end
  if state.char_factions[characterId] then
    state.char_factions[characterId][factionId] = nil
  end
  if state.online_roster[factionId] then
    state.online_roster[factionId][characterId] = nil
  end
end

function RPSTACK_FACTIONS_CACHE.updateMemberRank(factionId, characterId, rankId)
  local state = RPSTACK_FACTIONS_STATE
  if state.members[factionId] then
    state.members[factionId][characterId] = rankId
  end
  if state.char_factions[characterId] then
    state.char_factions[characterId][factionId] = rankId
  end
end

function RPSTACK_FACTIONS_CACHE.setOnline(factionId, characterId)
  local state = RPSTACK_FACTIONS_STATE
  if state.online_roster[factionId] then
    state.online_roster[factionId][characterId] = true
  end
end

function RPSTACK_FACTIONS_CACHE.setOffline(characterId)
  local state = RPSTACK_FACTIONS_STATE
  if state.char_factions[characterId] then
    for factionId in pairs(state.char_factions[characterId]) do
      if state.online_roster[factionId] then
        state.online_roster[factionId][characterId] = nil
      end
    end
  end
end

function RPSTACK_FACTIONS_CACHE.setRelationship(factionAId, factionBId, status)
  local state = RPSTACK_FACTIONS_STATE
  if state.relationships[factionAId] then
    state.relationships[factionAId][factionBId] = status
  end
  if state.relationships[factionBId] then
    state.relationships[factionBId][factionAId] = status
  end
end

-- ── Internal helpers ──────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_CACHE._rowToRank(row)
  return {
    id           = row.id,
    faction_id   = row.faction_id,
    name         = row.name,
    level        = row.level,
    can_recruit  = row.can_recruit  == 1,
    can_kick     = row.can_kick     == 1,
    can_deposit  = row.can_deposit  == 1,
    can_withdraw = row.can_withdraw == 1,
    can_promote  = row.can_promote  == 1,
    can_disband  = row.can_disband  == 1,
    can_declare  = row.can_declare  == 1,
  }
end