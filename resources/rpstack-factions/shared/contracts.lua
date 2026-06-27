-- rpstack-factions/shared/contracts.lua
-- Documents every public export: expected input, output shape, error codes.
-- Not enforced at runtime in v0 — serves as authoritative API reference.

RPSTACK_FACTIONS_CONTRACTS = {

  -- ── Faction CRUD ──────────────────────────────────────────────────────────

  createFaction = {
    input  = { "payload:table {name:string, tag:string, type:string, founderCharId:number}" },
    output = { "ok:boolean", "faction:table|nil", "error:string|nil" },
    notes  = "Creates faction + default rank ladder + treasury account. Founder is assigned top rank.",
  },

  getFaction = {
    input  = { "factionId:number" },
    output = { "ok:boolean", "faction:table|nil", "error:string|nil" },
  },

  getFactionByTag = {
    input  = { "tag:string" },
    output = { "ok:boolean", "faction:table|nil", "error:string|nil" },
  },

  listFactions = {
    input  = {},
    output = { "ok:boolean", "factions:table[]" },
    notes  = "Returns all active factions from cache. O(1).",
  },

  disbandFaction = {
    input  = { "factionId:number", "actorCharId:number" },
    output = { "ok:boolean", "error:string|nil" },
    notes  = "Actor must have can_disband permission. Fires FACTION_EVENTS.DISBANDED.",
  },

  -- ── Membership ────────────────────────────────────────────────────────────

  joinFaction = {
    input  = { "factionId:number", "characterId:number", "rankId:number", "actorCharId:number" },
    output = { "ok:boolean", "error:string|nil" },
    notes  = "Actor must have can_recruit. Respects max_factions_per_character config limit.",
  },

  leaveFaction = {
    input  = { "factionId:number", "characterId:number" },
    output = { "ok:boolean", "error:string|nil" },
    notes  = "Leader cannot leave if they are the sole member. Must disband or transfer first.",
  },

  kickMember = {
    input  = { "factionId:number", "characterId:number", "actorCharId:number" },
    output = { "ok:boolean", "error:string|nil" },
    notes  = "Actor must have can_kick. Cannot kick someone of equal or higher rank level.",
  },

  setMemberRank = {
    input  = { "factionId:number", "characterId:number", "rankId:number", "actorCharId:number" },
    output = { "ok:boolean", "error:string|nil" },
    notes  = "Actor must have can_promote. Cannot promote to own rank level or above.",
  },

  getCharacterFactions = {
    input  = { "characterId:number" },
    output = { "ok:boolean", "factions:table[]", "error:string|nil" },
    notes  = "Returns [{faction, rankId, rank}]. O(1) from reverse index cache.",
  },

  getFactionMembers = {
    input  = { "factionId:number" },
    output = { "ok:boolean", "members:table[]", "error:string|nil" },
    notes  = "Returns [{characterId, rankId}]. O(1) from cache.",
  },

  getOnlineRoster = {
    input  = { "factionId:number" },
    output = { "ok:boolean", "roster:table[]", "error:string|nil" },
    notes  = "Returns [{characterId, rankId}] for currently online members only. O(1).",
  },

  -- ── Permission checks (O(1) — safe to call on every action) ──────────────

  characterHasFactionPerm = {
    input  = { "factionId:number", "characterId:number", "perm:string" },
    output = { "ok:boolean", "allowed:boolean", "error:string|nil" },
    notes  = "perm is a FACTION_PERMS value. Pure cache read, no DB.",
  },

  getCharacterFactionRank = {
    input  = { "factionId:number", "characterId:number" },
    output = { "ok:boolean", "rank:table|nil", "error:string|nil" },
    notes  = "Returns full rank table or nil if not a member. Pure cache read.",
  },

  isMember = {
    input  = { "factionId:number", "characterId:number" },
    output = { "ok:boolean", "member:boolean" },
    notes  = "Fastest membership check. Pure cache read.",
  },

  -- ── Ranks ─────────────────────────────────────────────────────────────────

  createRank = {
    input  = { "factionId:number", "payload:table {name:string, level:number, ...perms}", "actorCharId:number" },
    output = { "ok:boolean", "rank:table|nil", "error:string|nil" },
  },

  updateRank = {
    input  = { "factionId:number", "rankId:number", "payload:table", "actorCharId:number" },
    output = { "ok:boolean", "error:string|nil" },
  },

  getRanks = {
    input  = { "factionId:number" },
    output = { "ok:boolean", "ranks:table[]" },
    notes  = "Pure cache read. O(1).",
  },

  -- ── Relationships ─────────────────────────────────────────────────────────

  setRelationship = {
    input  = { "factionAId:number", "factionBId:number", "status:string", "actorCharId:number" },
    output = { "ok:boolean", "error:string|nil" },
    notes  = "status is a FACTION_RELATIONSHIP value. Actor must have can_declare in faction A.",
  },

  getRelationship = {
    input  = { "factionAId:number", "factionBId:number" },
    output = { "ok:boolean", "status:string" },
    notes  = "Returns FACTION_RELATIONSHIP.NEUTRAL if no record exists. Pure cache read.",
  },

  getFactionAllies = {
    input  = { "factionId:number" },
    output = { "ok:boolean", "factions:table[]" },
  },

  getFactionHostiles = {
    input  = { "factionId:number" },
    output = { "ok:boolean", "factions:table[]" },
  },

  -- ── Treasury ──────────────────────────────────────────────────────────────
  -- ASYNC: treasury exports require a callback as the final argument.
  -- All other faction exports are synchronous (pure cache).
  -- Asymmetry exists because rpstack-economy balance mutations are callback-based.

  depositToTreasury = {
    input  = { "factionId:number", "characterId:number", "amount:number", "note:string", "cb:function" },
    output = { "ok:boolean", "newBalance:number|nil", "error:string|nil" },
    notes  = "ASYNC. Character must have can_deposit. Deducts from character cash. Serialized per faction.",
  },

  withdrawFromTreasury = {
    input  = { "factionId:number", "characterId:number", "amount:number", "note:string", "cb:function" },
    output = { "ok:boolean", "newBalance:number|nil", "error:string|nil" },
    notes  = "ASYNC. Character must have can_withdraw. Adds to character cash. Serialized per faction.",
  },

  getTreasuryBalance = {
    input  = { "factionId:number", "cb:function" },
    output = { "ok:boolean", "cash:number", "bank:number", "error:string|nil" },
    notes  = "ASYNC. Hits economy DB — not a cache read.",
  },

  getTreasuryLedger = {
    input  = { "factionId:number", "limit:number", "cb:function" },
    output = { "ok:boolean", "entries:table[]", "error:string|nil" },
    notes  = "ASYNC. Returns most recent N faction_audit_log entries for treasury actions.",
  },
}