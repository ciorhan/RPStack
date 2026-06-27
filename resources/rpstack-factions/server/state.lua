-- rpstack-factions/server/state.lua
-- Declares the in-memory state structure.
-- All keys initialized empty; cache.lua hydrates them on startup.
--
-- Read performance targets (128+ players):
--   isMember, getCharacterFactionRank, characterHasFactionPerm — O(1), no DB
--   getOnlineRoster — O(1), no DB
--   getFactionMembers — O(1), no DB
--   getRelationship — O(1), no DB

RPSTACK_FACTIONS_STATE = {

  -- Primary faction data, keyed by faction id
  -- [faction_id] = { id, name, tag, type, description, is_active, created_at }
  factions = {},

  -- Tag → faction_id lookup for fast getFactionByTag
  -- [tag_string] = faction_id
  tags = {},

  -- Rank tables per faction, keyed by rank id
  -- [faction_id] = { [rank_id] = { id, faction_id, name, level, can_recruit, ... } }
  ranks = {},

  -- Level → rank_id per faction (for finding the top rank on creation)
  -- [faction_id] = { [level] = rank_id }
  rank_by_level = {},

  -- Membership: faction view
  -- [faction_id] = { [character_id] = rank_id }
  members = {},

  -- Membership: character reverse index (the hot path for per-action checks)
  -- [character_id] = { [faction_id] = rank_id }
  char_factions = {},

  -- Online roster: updated by identity session events, never hits DB
  -- [faction_id] = { [character_id] = true }
  online_roster = {},

  -- Faction relationships
  -- [faction_a_id] = { [faction_b_id] = "ally"|"neutral"|"hostile" }
  -- Both directions stored: [a][b] and [b][a] always kept in sync
  relationships = {},

  -- Treasury mutex: prevents concurrent deposit/withdraw races per faction
  -- [faction_id] = true when locked, nil when free
  treasury_locked = {},

  -- Internal: set to true once cache hydration is complete
  _ready = false,
}