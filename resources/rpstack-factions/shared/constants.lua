-- rpstack-factions/shared/constants.lua
-- Single source of truth for all magic strings used across the module.
-- Shared so client scripts can reference types/perms without hardcoding.

FACTION_TYPES = {
  GANG      = "gang",
  GUILD     = "guild",
  POLITICAL = "political",
  LAW       = "law",
}

-- All valid types as a set for fast validation
FACTION_TYPES_SET = {
  gang      = true,
  guild     = true,
  political = true,
  law       = true,
}

-- Permission flag keys — match column names in faction_ranks table.
-- Use with exports['rpstack-factions']:characterHasFactionPerm(factionId, charId, FACTION_PERMS.RECRUIT)
FACTION_PERMS = {
  RECRUIT  = "can_recruit",
  KICK     = "can_kick",
  DEPOSIT  = "can_deposit",
  WITHDRAW = "can_withdraw",
  PROMOTE  = "can_promote",
  DISBAND  = "can_disband",
  DECLARE  = "can_declare",   -- declare war or alliance
}

FACTION_PERMS_SET = {}
for _, permission in pairs(FACTION_PERMS) do
  FACTION_PERMS_SET[permission] = true
end

FACTION_RELATIONSHIP = {
  ALLY    = "ally",
  NEUTRAL = "neutral",
  HOSTILE = "hostile",
}

-- Audit action strings — kept here so downstream modules can reference them
FACTION_AUDIT = {
  CREATED              = "faction_created",
  DISBANDED            = "faction_disbanded",
  MEMBER_JOINED        = "member_joined",
  MEMBER_LEFT          = "member_left",
  MEMBER_KICKED        = "member_kicked",
  RANK_CHANGED         = "rank_changed",
  RANK_CREATED         = "rank_created",
  RANK_UPDATED         = "rank_updated",
  RELATIONSHIP_CHANGED = "relationship_changed",
  TREASURY_DEPOSIT     = "treasury_deposit",
  TREASURY_WITHDRAW    = "treasury_withdraw",
}

-- Events emitted by this module (for downstream listeners)
FACTION_EVENTS = {
  READY                = "rpstack:factions:ready",
  MEMBER_JOINED        = "rpstack:factions:memberJoined",
  MEMBER_LEFT          = "rpstack:factions:memberLeft",
  MEMBER_KICKED        = "rpstack:factions:memberKicked",
  RANK_CHANGED         = "rpstack:factions:rankChanged",
  RELATIONSHIP_CHANGED = "rpstack:factions:relationshipChanged",
  DISBANDED            = "rpstack:factions:disbanded",
  TREASURY_CHANGED     = "rpstack:factions:treasuryChanged",
}