local source = debug.getinfo(1, "S").source
if source:sub(1, 1) == "@" then source = source:sub(2) end
local testDir = source:match("^(.*)[/\\][^/\\]+$") or "."
local repoRoot = testDir .. "/../.."

RPSTACK_ERRORS = {
  VALIDATION_FAILED = "VALIDATION_FAILED",
  NOT_AUTHORIZED = "NOT_AUTHORIZED",
  NOT_FOUND = "NOT_FOUND",
  CONFLICT = "CONFLICT",
  INTERNAL = "INTERNAL",
}

FACTION_PERMS = {
  RECRUIT = "can_recruit",
  KICK = "can_kick",
  DEPOSIT = "can_deposit",
  WITHDRAW = "can_withdraw",
  PROMOTE = "can_promote",
  DISBAND = "can_disband",
  DECLARE = "can_declare",
}

FACTION_PERMS_SET = {}
for _, permission in pairs(FACTION_PERMS) do
  FACTION_PERMS_SET[permission] = true
end

FACTION_AUDIT = { RANK_CREATED = "rank_created", RANK_UPDATED = "rank_updated" }

dofile(repoRoot .. "/resources/rpstack-factions/server/ranks.lua")

local factionId = 1
local actorCharId = 10

local function rank(id, name, level, permissions)
  local value = {
    id = id,
    faction_id = factionId,
    name = name,
    level = level,
    can_recruit = false,
    can_kick = false,
    can_deposit = false,
    can_withdraw = false,
    can_promote = false,
    can_disband = false,
    can_declare = false,
  }
  for key, enabled in pairs(permissions or {}) do value[key] = enabled end
  return value
end

local function resetFixture()
  local actor = rank(100, "Officer", 2, {
    can_recruit = true,
    can_kick = true,
    can_deposit = true,
    can_promote = true,
  })
  local lower = rank(101, "Member", 1)
  local equal = rank(102, "Peer", 2)
  local higher = rank(103, "Founder", 3, {
    can_recruit = true,
    can_kick = true,
    can_deposit = true,
    can_withdraw = true,
    can_promote = true,
    can_disband = true,
    can_declare = true,
  })

  RPSTACK_FACTIONS_STATE = {
    char_factions = { [actorCharId] = { [factionId] = actor.id } },
    ranks = { [factionId] = {
      [actor.id] = actor,
      [lower.id] = lower,
      [equal.id] = equal,
      [higher.id] = higher,
    } },
    rank_by_level = { [factionId] = {
      [lower.level] = lower.id,
      [actor.level] = actor.id,
      [higher.level] = higher.id,
    } },
  }

  RPSTACK_FACTIONS_MEMBERSHIP = {
    getCharacterFactionRank = function()
      return { ok = true, rank = actor }
    end,
  }

  local writes = { inserts = 0, updates = 0, audits = 0, cache = 0 }
  local persistedPermissions = nil
  RPSTACK_FACTIONS_REPO = {
    insertRank = function(_, _, _, _, cb)
      writes.inserts = writes.inserts + 1
      cb(999)
    end,
    updateRank = function(_, _, _, permissions, cb)
      writes.updates = writes.updates + 1
      persistedPermissions = permissions
      cb(1)
    end,
  }
  RPSTACK_FACTIONS_CACHE = {
    addRank = function() writes.cache = writes.cache + 1 end,
    updateRank = function() writes.cache = writes.cache + 1 end,
  }
  RPSTACK_FACTIONS_AUDIT = {
    log = function() writes.audits = writes.audits + 1 end,
  }

  return {
    actor = actor,
    lower = lower,
    equal = equal,
    higher = higher,
    writes = writes,
    persistedPermissions = function() return persistedPermissions end,
  }
end

local function updateRank(fixture, rankId, payload)
  local result = nil
  RPSTACK_FACTIONS_RANKS.updateRank(
    factionId,
    rankId,
    payload,
    actorCharId,
    function(value) result = value end
  )
  assert(result ~= nil, "updateRank callback must complete")
  return result
end

local function createRank(payload)
  local result = nil
  RPSTACK_FACTIONS_RANKS.createRank(
    factionId,
    payload,
    actorCharId,
    function(value) result = value end
  )
  assert(result ~= nil, "createRank callback must complete")
  return result
end

local function assertZeroWrites(name, writes)
  assert(writes.inserts == 0, name .. " must not insert")
  assert(writes.updates == 0, name .. " must not update")
  assert(writes.audits == 0, name .. " must not audit")
  assert(writes.cache == 0, name .. " must not mutate cache")
end

local function rejectedUpdate(name, target, payload, expectedError)
  local fixture = resetFixture()
  local rankId = target(fixture).id
  local result = updateRank(fixture, rankId, payload(fixture))
  assert(result.ok == false and result.error == expectedError, name .. " wrong result")
  assertZeroWrites(name, fixture.writes)
end

rejectedUpdate(
  "self-rank modification",
  function(fixture) return fixture.actor end,
  function() return { name = "Escalated" } end,
  RPSTACK_ERRORS.NOT_AUTHORIZED
)

rejectedUpdate(
  "equal-rank modification",
  function(fixture) return fixture.equal end,
  function() return { name = "Escalated" } end,
  RPSTACK_ERRORS.NOT_AUTHORIZED
)

rejectedUpdate(
  "higher-rank modification",
  function(fixture) return fixture.higher end,
  function() return { name = "Escalated" } end,
  RPSTACK_ERRORS.NOT_AUTHORIZED
)

rejectedUpdate(
  "excessive resulting level",
  function(fixture) return fixture.lower end,
  function(fixture) return { level = fixture.actor.level } end,
  RPSTACK_ERRORS.NOT_AUTHORIZED
)

rejectedUpdate(
  "unknown payload field",
  function(fixture) return fixture.lower end,
  function() return { metadata = "unsupported" } end,
  RPSTACK_ERRORS.VALIDATION_FAILED
)

rejectedUpdate(
  "unknown permission field",
  function(fixture) return fixture.lower end,
  function() return { can_superuser = true } end,
  RPSTACK_ERRORS.VALIDATION_FAILED
)

rejectedUpdate(
  "unauthorized permission update",
  function(fixture) return fixture.lower end,
  function() return { can_disband = true } end,
  RPSTACK_ERRORS.NOT_AUTHORIZED
)

do
  local fixture = resetFixture()
  local result = createRank({
    name = "Escalated",
    level = 0,
    can_disband = true,
  })
  assert(
    result.ok == false and result.error == RPSTACK_ERRORS.NOT_AUTHORIZED,
    "unauthorized permission creation wrong result"
  )
  assertZeroWrites("unauthorized permission creation", fixture.writes)
end

do
  local fixture = resetFixture()
  local result = updateRank(fixture, fixture.lower.id, { name = fixture.lower.name })
  assert(result.ok == true, "omitted false permission update should succeed")
  assert(fixture.writes.inserts == 0, "omitted false permission must not insert")
  assert(fixture.writes.updates == 1, "omitted false permission should update once")
  assert(fixture.writes.audits == 1, "successful update should audit once")
  assert(fixture.writes.cache == 1, "successful update should update cache once")
  assert(
    fixture.persistedPermissions().can_deposit == false,
    "omitted can_deposit must preserve existing false"
  )
end

print("PASS factions_rank_permissions: 9 authorization and merge regressions")
