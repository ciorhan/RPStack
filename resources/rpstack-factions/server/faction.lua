-- rpstack-factions/server/faction.lua
-- Faction creation, retrieval, disbandment. All writes are async.

RPSTACK_FACTIONS_FACTION = {}

-- ── Reads (pure cache — O(1)) ─────────────────────────────────────────────────

function RPSTACK_FACTIONS_FACTION.getFaction(factionId)
  local faction = RPSTACK_FACTIONS_STATE.factions[factionId]
  if not faction then return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND } end
  return { ok = true, faction = faction }
end

function RPSTACK_FACTIONS_FACTION.getFactionByTag(tag)
  local factionId = RPSTACK_FACTIONS_STATE.tags[tag]
  if not factionId then return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND } end
  return RPSTACK_FACTIONS_FACTION.getFaction(factionId)
end

function RPSTACK_FACTIONS_FACTION.listFactions()
  local list = {}
  for _, faction in pairs(RPSTACK_FACTIONS_STATE.factions) do
    table.insert(list, faction)
  end
  return { ok = true, factions = list }
end

-- ── Create ────────────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_FACTION.createFaction(payload, cb)
  if type(payload) ~= "table" then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end

  local name          = payload.name
  local tag           = payload.tag
  local factionType   = payload.type
  local founderCharId = payload.founderCharId

  if type(name) ~= "string" or #name < RPSTACK_FACTIONS_CONFIG.name_min_length or #name > RPSTACK_FACTIONS_CONFIG.name_max_length then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end
  if type(tag) ~= "string" or #tag < RPSTACK_FACTIONS_CONFIG.tag_min_length or #tag > RPSTACK_FACTIONS_CONFIG.tag_max_length then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end
  if not FACTION_TYPES_SET[factionType] then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end
  if type(founderCharId) ~= "number" or founderCharId <= 0 then
    return cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
  end

  -- Conflict checks from cache
  if RPSTACK_FACTIONS_STATE.tags[tag] then
    return cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT })
  end
  for _, f in pairs(RPSTACK_FACTIONS_STATE.factions) do
    if f.name == name then return cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT }) end
  end

  -- Insert faction row
  RPSTACK_FACTIONS_REPO.insertFaction(name, tag, factionType, payload.description, function(factionId)
    if not factionId then
      return cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
    end

    local faction = {
      id          = factionId,
      name        = name,
      tag         = tag,
      type        = factionType,
      description = payload.description or "",
      is_active   = true,
      created_at  = os.time(),
    }

    -- Add to cache before rank seeding so rank cache keys exist
    RPSTACK_FACTIONS_CACHE.addFaction(faction)

    -- Seed default ranks then add founder
    RPSTACK_FACTIONS_RANKS.seedDefaults(factionId, factionType, function(topRankId)
      local function finalize()
        -- Create treasury account via economy
        local econ = exports["rpstack-economy"]
        econ['rpstack:economy:createAccountForOwner'](econ, "faction", factionId, "treasury", function(r)
          if not r or not r.ok then
            RPSTACK_LOG.warn("factions", "treasury account creation failed", { factionId = factionId })
          end
        end)

        RPSTACK_FACTIONS_AUDIT.log(factionId, founderCharId, FACTION_AUDIT.CREATED, {
          name = name, tag = tag, type = factionType
        })

        RPSTACK_LOG.info("factions", "faction created", {
          factionId = factionId, name = name, tag = tag, founder = founderCharId
        })

        TriggerEvent(FACTION_EVENTS.MEMBER_JOINED, {
          factionId = factionId, characterId = founderCharId, rankId = topRankId
        })

        cb({ ok = true, faction = faction })
      end

      if topRankId then
        RPSTACK_FACTIONS_REPO.insertMember(factionId, founderCharId, topRankId, function()
          RPSTACK_FACTIONS_CACHE.addMember(factionId, founderCharId, topRankId)
          finalize()
        end)
      else
        RPSTACK_LOG.warn("factions", "faction created without default ranks", { factionId = factionId })
        finalize()
      end
    end)
  end)
end

-- ── Disband ───────────────────────────────────────────────────────────────────

function RPSTACK_FACTIONS_FACTION.disbandFaction(factionId, actorCharId, cb)
  if not RPSTACK_FACTIONS_STATE.factions[factionId] then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
  end
  if not RPSTACK_FACTIONS_RANKS.hasPerm(factionId, actorCharId, FACTION_PERMS.DISBAND) then
    return cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
  end

  RPSTACK_FACTIONS_REPO.markDisbanded(factionId, function()
    RPSTACK_FACTIONS_AUDIT.log(factionId, actorCharId, FACTION_AUDIT.DISBANDED, {})
    RPSTACK_LOG.info("factions", "faction disbanded", { factionId = factionId, actor = actorCharId })
    TriggerEvent(FACTION_EVENTS.DISBANDED, { factionId = factionId })
    RPSTACK_FACTIONS_CACHE.removeFaction(factionId)
    cb({ ok = true })
  end)
end