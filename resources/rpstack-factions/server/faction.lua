-- Faction creation, retrieval, and disbandment.

RPSTACK_FACTIONS_FACTION = {}

local function isPositiveInteger(value)
  return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function trim(value)
  return value:match("^%s*(.-)%s*$")
end

local function failCreation(factionId, cb)
  RPSTACK_FACTIONS_REPO.markDisbanded(factionId, function()
    RPSTACK_FACTIONS_CACHE.removeFaction(factionId)
    cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
  end)
end

function RPSTACK_FACTIONS_FACTION.getFaction(factionId)
  if not isPositiveInteger(factionId) then
    return { ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }
  end
  local faction = RPSTACK_FACTIONS_STATE.factions[factionId]
  if not faction then return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND } end
  return { ok = true, faction = faction }
end

function RPSTACK_FACTIONS_FACTION.getFactionByTag(tag)
  if type(tag) ~= "string" then
    return { ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED }
  end
  local factionId = RPSTACK_FACTIONS_STATE.tags[string.upper(trim(tag))]
  if not factionId then return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND } end
  return RPSTACK_FACTIONS_FACTION.getFaction(factionId)
end

function RPSTACK_FACTIONS_FACTION.listFactions()
  local list = {}
  for _, faction in pairs(RPSTACK_FACTIONS_STATE.factions) do
    list[#list + 1] = faction
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return { ok = true, factions = list }
end

local function persistFaction(
  name,
  tag,
  factionType,
  description,
  founderCharId,
  cb
)
  RPSTACK_FACTIONS_REPO.insertFaction(
    name,
    tag,
    factionType,
    description,
    function(factionId)
      if not factionId then
        cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT })
        return
      end

      local faction = {
        id = factionId,
        name = name,
        tag = tag,
        type = factionType,
        description = description,
        is_active = true,
        created_at = os.time(),
      }
      RPSTACK_FACTIONS_CACHE.addFaction(faction)

      RPSTACK_FACTIONS_RANKS.seedDefaults(
        factionId,
        factionType,
        function(topRankId, ranksCreated)
          if not ranksCreated then
            RPSTACK_LOG.error("factions", "default rank creation failed", {
              factionId = factionId,
            })
            failCreation(factionId, cb)
            return
          end

          RPSTACK_FACTIONS_REPO.insertMember(
            factionId,
            founderCharId,
            topRankId,
            function(memberId)
              if not memberId then
                RPSTACK_LOG.error("factions", "founder membership failed", {
                  factionId = factionId,
                  founderCharId = founderCharId,
                })
                failCreation(factionId, cb)
                return
              end

              local econ = exports["rpstack-economy"]
              local ok, err = pcall(function()
                econ['rpstack:economy:createAccountForOwner'](
                  econ,
                  "faction",
                  factionId,
                  "treasury",
                  function(result)
                    if not result or not result.ok then
                      RPSTACK_LOG.error("factions", "treasury creation failed", {
                        factionId = factionId,
                      })
                      failCreation(factionId, cb)
                      return
                    end

                    RPSTACK_FACTIONS_CACHE.addMember(
                      factionId,
                      founderCharId,
                      topRankId
                    )
                    RPSTACK_FACTIONS_AUDIT.log(
                      factionId,
                      founderCharId,
                      FACTION_AUDIT.CREATED,
                      { name = name, tag = tag, type = factionType }
                    )
                    TriggerEvent(FACTION_EVENTS.MEMBER_JOINED, {
                      factionId = factionId,
                      characterId = founderCharId,
                      rankId = topRankId,
                    })
                    cb({ ok = true, faction = faction })
                  end
                )
              end)
              if not ok then
                RPSTACK_LOG.error("factions", "economy export failed", {
                  factionId = factionId,
                  error = tostring(err),
                })
                failCreation(factionId, cb)
              end
            end
          )
        end
      )
    end
  )
end

function RPSTACK_FACTIONS_FACTION.createFaction(payload, cb)
  if type(cb) ~= "function" then
    RPSTACK_LOG.error("factions", "create callback missing")
    return
  end
  if type(payload) ~= "table" then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end

  local name = type(payload.name) == "string" and trim(payload.name) or nil
  local tag = type(payload.tag) == "string"
    and string.upper(trim(payload.tag))
    or nil
  local factionType = payload.type
  local founderCharId = payload.founderCharId
  local description = payload.description == nil and "" or payload.description

  if not name
    or #name < RPSTACK_FACTIONS_CONFIG.name_min_length
    or #name > RPSTACK_FACTIONS_CONFIG.name_max_length
    or not tag
    or #tag < RPSTACK_FACTIONS_CONFIG.tag_min_length
    or #tag > RPSTACK_FACTIONS_CONFIG.tag_max_length
    or tag:match("^[A-Z0-9]+$") == nil
    or not FACTION_TYPES_SET[factionType]
    or not isPositiveInteger(founderCharId)
    or type(description) ~= "string"
    or #description > 512
  then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end

  local founderFactions = RPSTACK_FACTIONS_STATE.char_factions[founderCharId] or {}
  local founderFactionCount = 0
  for _ in pairs(founderFactions) do
    founderFactionCount = founderFactionCount + 1
  end
  if founderFactionCount >= RPSTACK_FACTIONS_CONFIG.max_factions_per_character then
    cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT })
    return
  end

  if RPSTACK_FACTIONS_STATE.tags[tag] then
    cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT })
    return
  end
  local normalizedName = string.lower(name)
  for _, faction in pairs(RPSTACK_FACTIONS_STATE.factions) do
    if string.lower(faction.name) == normalizedName then
      cb({ ok = false, error = RPSTACK_ERRORS.CONFLICT })
      return
    end
  end

  local identity = exports["rpstack-identity"]
  local ok, err = pcall(function()
    identity['rpstack:identity:getCharacterById'](
      identity,
      founderCharId,
      function(result)
        RPSTACK_LOG.debug("factions", "founder lookup completed", {
          founderCharId = founderCharId,
          ok = result and result.ok == true,
        })
        if not result or not result.ok then
          cb({
            ok = false,
            error = result and result.error or RPSTACK_ERRORS.NOT_FOUND,
          })
          return
        end
        persistFaction(
          name,
          tag,
          factionType,
          description,
          founderCharId,
          cb
        )
      end
    )
  end)
  if not ok then
    RPSTACK_LOG.error("factions", "identity export failed", {
      founderCharId = founderCharId,
      error = tostring(err),
    })
    cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
  end
end

function RPSTACK_FACTIONS_FACTION.disbandFaction(factionId, actorCharId, cb)
  if type(cb) ~= "function" then return end
  if not isPositiveInteger(factionId) or not isPositiveInteger(actorCharId) then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end
  if not RPSTACK_FACTIONS_STATE.factions[factionId] then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    return
  end
  if not RPSTACK_FACTIONS_RANKS.hasPerm(
    factionId,
    actorCharId,
    FACTION_PERMS.DISBAND
  ) then
    cb({ ok = false, error = RPSTACK_ERRORS.NOT_AUTHORIZED })
    return
  end

  RPSTACK_FACTIONS_REPO.markDisbanded(factionId, function(affected)
    if affected ~= 1 then
      cb({ ok = false, error = RPSTACK_ERRORS.INTERNAL })
      return
    end
    RPSTACK_FACTIONS_AUDIT.log(
      factionId,
      actorCharId,
      FACTION_AUDIT.DISBANDED,
      {}
    )
    TriggerEvent(FACTION_EVENTS.DISBANDED, { factionId = factionId })
    RPSTACK_FACTIONS_CACHE.removeFaction(factionId)
    cb({ ok = true })
  end)
end
