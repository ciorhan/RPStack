-- rpstack-factions/server/repository.lua
-- All database operations. No business logic. No cache writes. No event firing.
-- All functions are async with callbacks matching RPSTACK_DB pattern.
-- Uses rpstack_* table prefix matching the project convention.

RPSTACK_FACTIONS_REPO = {}

-- ── Startup hydration ─────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_REPO.loadAllFactions(cb)
  RPSTACK_DB.query(
    "SELECT id, name, tag, type, description, is_active, created_at, disbanded_at FROM rpstack_factions WHERE is_active = 1",
    {}, cb
  )
end

function RPSTACK_FACTIONS_REPO.loadAllRanks(cb)
  RPSTACK_DB.query(
    "SELECT id, faction_id, name, level, can_recruit, can_kick, can_deposit, can_withdraw, can_promote, can_disband, can_declare FROM rpstack_faction_ranks ORDER BY faction_id, level ASC",
    {}, cb
  )
end

function RPSTACK_FACTIONS_REPO.loadAllMembers(cb)
  RPSTACK_DB.query(
    "SELECT id, faction_id, character_id, rank_id, joined_at FROM rpstack_faction_members",
    {}, cb
  )
end

function RPSTACK_FACTIONS_REPO.loadAllRelationships(cb)
  RPSTACK_DB.query(
    "SELECT faction_a_id, faction_b_id, status FROM rpstack_faction_relationships",
    {}, cb
  )
end

-- ── Faction CRUD ──────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_REPO.insertFaction(name, tag, factionType, description, cb)
  RPSTACK_DB.insert(
    "INSERT INTO rpstack_factions (name, tag, type, description, is_active, created_at) VALUES (?, ?, ?, ?, 1, ?)",
    { name, tag, factionType, description or "", os.time() },
    cb
  )
end

function RPSTACK_FACTIONS_REPO.markDisbanded(factionId, cb)
  RPSTACK_DB.execute(
    "UPDATE rpstack_factions SET is_active = 0, disbanded_at = ? WHERE id = ?",
    { os.time(), factionId },
    cb
  )
end

-- ── Ranks ─────────────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_REPO.insertRank(factionId, name, level, perms, cb)
  RPSTACK_DB.insert(
    "INSERT INTO rpstack_faction_ranks (faction_id, name, level, can_recruit, can_kick, can_deposit, can_withdraw, can_promote, can_disband, can_declare) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    {
      factionId, name, level,
      perms.can_recruit  and 1 or 0,
      perms.can_kick     and 1 or 0,
      perms.can_deposit  and 1 or 0,
      perms.can_withdraw and 1 or 0,
      perms.can_promote  and 1 or 0,
      perms.can_disband  and 1 or 0,
      perms.can_declare  and 1 or 0,
    },
    cb
  )
end

function RPSTACK_FACTIONS_REPO.updateRank(rankId, name, level, perms, cb)
  RPSTACK_DB.execute(
    "UPDATE rpstack_faction_ranks SET name = ?, level = ?, can_recruit = ?, can_kick = ?, can_deposit = ?, can_withdraw = ?, can_promote = ?, can_disband = ?, can_declare = ? WHERE id = ?",
    {
      name, level,
      perms.can_recruit  and 1 or 0,
      perms.can_kick     and 1 or 0,
      perms.can_deposit  and 1 or 0,
      perms.can_withdraw and 1 or 0,
      perms.can_promote  and 1 or 0,
      perms.can_disband  and 1 or 0,
      perms.can_declare  and 1 or 0,
      rankId,
    },
    cb
  )
end

-- ── Membership ────────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_REPO.insertMember(factionId, characterId, rankId, cb)
  RPSTACK_DB.insert(
    "INSERT INTO rpstack_faction_members (faction_id, character_id, rank_id, joined_at) VALUES (?, ?, ?, ?)",
    { factionId, characterId, rankId, os.time() },
    cb
  )
end

function RPSTACK_FACTIONS_REPO.deleteMember(factionId, characterId, cb)
  RPSTACK_DB.execute(
    "DELETE FROM rpstack_faction_members WHERE faction_id = ? AND character_id = ?",
    { factionId, characterId },
    cb
  )
end

function RPSTACK_FACTIONS_REPO.updateMemberRank(factionId, characterId, rankId, cb)
  RPSTACK_DB.execute(
    "UPDATE rpstack_faction_members SET rank_id = ? WHERE faction_id = ? AND character_id = ?",
    { rankId, factionId, characterId },
    cb
  )
end

-- ── Relationships ─────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_REPO.upsertRelationship(factionAId, factionBId, status, actorCharId, cb)
  RPSTACK_DB.execute(
    "INSERT INTO rpstack_faction_relationships (faction_a_id, faction_b_id, status, declared_by, declared_at) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE status = VALUES(status), declared_by = VALUES(declared_by), declared_at = VALUES(declared_at)",
    { factionAId, factionBId, status, actorCharId, os.time() },
    cb
  )
end

-- ── Audit log ─────────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_REPO.insertAudit(factionId, actorCharId, action, payloadJson)
  -- Fire and forget — no callback needed
  RPSTACK_DB.insert(
    "INSERT INTO rpstack_faction_audit_log (faction_id, actor_char_id, action, payload, created_at) VALUES (?, ?, ?, ?, ?)",
    { factionId, actorCharId, action, payloadJson or "", os.time() },
    function() end
  )
end

function RPSTACK_FACTIONS_REPO.getTreasuryLedger(factionId, limit, cb)
  RPSTACK_DB.query(
    "SELECT id, actor_char_id, action, payload, created_at FROM rpstack_faction_audit_log WHERE faction_id = ? AND action LIKE 'treasury_%' ORDER BY created_at DESC LIMIT ?",
    { factionId, limit or 50 },
    cb
  )
end