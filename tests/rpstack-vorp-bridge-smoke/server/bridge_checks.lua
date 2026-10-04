if not RPSTACK_VSMOKE_ENABLED then return end

-- ── N1 / N2 ───────────────────────────────────────────────────────────────────

local function checkN2(label, characterId, expect)
  local bridge = VSMOKE.bridge()
  local done = false
  SetTimeout(5000, function()
    if not done then VSMOKE.report(label, false, { error = 'callback timeout' }) end
  end)
  bridge['rpstack:identity:getCharacterById'](bridge, characterId, function(result)
    done = true
    VSMOKE.report(label, expect(result), { characterId = characterId, result = result })
  end)
end

RegisterCommand('rpstack_bridge_smoke', function(source, args)
  if not VSMOKE.consoleOnly(source) then return end
  local usage = 'rpstack_bridge_smoke <playerSource> [offlineCharacterId]'
  local src = VSMOKE.playerArg(args, usage)
  if not src then return end
  local offlineId = tonumber(args[2])

  local bridge = VSMOKE.bridge()
  local vorpCharacter = VSMOKE.vorpCharacter(src)
  local active = bridge['rpstack:identity:getActiveCharacter'](bridge, src)

  local vorpId = vorpCharacter and tonumber(vorpCharacter.charIdentifier) or nil
  local n1ok = active and active.ok == true and active.character
    and active.character.id == vorpId
    and active.character.firstname == tostring(vorpCharacter.firstname or '')
    and active.character.lastname == tostring(vorpCharacter.lastname or '')
  VSMOKE.report('N1 getActiveCharacter online', n1ok == true, {
    source = src, vorpCharId = vorpId, result = active,
  })

  local invalid = bridge['rpstack:identity:getActiveCharacter'](bridge, -1)
  VSMOKE.report('N1 rejects invalid source', invalid and invalid.ok == false and invalid.error == 'VALIDATION_FAILED', {
    result = invalid,
  })

  if vorpId then
    checkN2('N2 getCharacterById online', vorpId, function(result)
      return result and result.ok == true and result.character
        and result.character.id == vorpId and result.character.online == true
    end)
  else
    VSMOKE.report('N2 getCharacterById online', false, { error = 'player has no active VORP character' })
  end

  if offlineId then
    checkN2('N2 getCharacterById offline', offlineId, function(result)
      return result and result.ok == true and result.character
        and result.character.id == offlineId and result.character.online == false
    end)
  else
    VSMOKE.info('N2 getCharacterById offline', 'skipped; pass an offline charidentifier as the second argument', {})
  end

  checkN2('N2 unknown id returns NOT_FOUND', 2147483647, function(result)
    return result and result.ok == false and result.error == 'NOT_FOUND'
  end)

  checkN2('N2 rejects invalid id', 0, function(result)
    return result and result.ok == false and result.error == 'VALIDATION_FAILED'
  end)
end, false)

-- ── N3 ────────────────────────────────────────────────────────────────────────
-- Events are recorded from the moment this resource starts. Each event also
-- records the player's Steam identifier so a reconnect (new source) can be
-- matched to the same player. Unloaded events are emitted from playerDropped,
-- where identifiers are still readable.

local observed = {}
local MAX_OBSERVED = 50

local function record(kind, data)
  local src = type(data) == 'table' and tonumber(data.source) or nil
  observed[#observed + 1] = {
    kind = kind,
    characterId = type(data) == 'table' and data.characterId or nil,
    source = src,
    steam = src and GetPlayerIdentifierByType(src, 'steam') or nil,
    at = os.time(),
  }
  if #observed > MAX_OBSERVED then table.remove(observed, 1) end
  print(('[SMOKE] observed %s %s'):format(kind, json.encode(data or {})))
end

AddEventHandler('rpstack:identity:characterLoaded', function(data) record('loaded', data) end)
AddEventHandler('rpstack:identity:characterUnloaded', function(data) record('unloaded', data) end)

RegisterCommand('rpstack_bridge_events_smoke', function(source, args)
  if not VSMOKE.consoleOnly(source) then return end

  print(('[SMOKE] observed events (%d): %s'):format(#observed, json.encode(observed)))

  local src = tonumber(args[1])
  if not src then
    VSMOKE.info('N3', 'pass the reconnected player source to evaluate', {})
    return
  end
  if GetPlayerName(src) == nil then
    print('[SMOKE] Usage: rpstack_bridge_events_smoke [playerSource]')
    return
  end

  local vorpCharacter = VSMOKE.vorpCharacter(src)
  local vorpId = vorpCharacter and tonumber(vorpCharacter.charIdentifier) or nil
  local steam = GetPlayerIdentifierByType(src, 'steam')

  -- Unloaded passes for any character on a previous source of the same player:
  -- the player may pick a different character after reconnecting.
  local loaded, unloaded = nil, nil
  for _, event in ipairs(observed) do
    if event.kind == 'loaded' and event.source == src and event.characterId == vorpId then
      loaded = event
    end
    if event.kind == 'unloaded' and steam and event.steam == steam and event.source ~= src then
      unloaded = event
    end
  end

  VSMOKE.report('N3 characterLoaded for current source', loaded ~= nil, {
    source = src, vorpCharId = vorpId, event = loaded,
  })
  VSMOKE.report('N3 characterUnloaded from a previous source of the same player', unloaded ~= nil, {
    source = src, event = unloaded,
    note = 'requires the player to disconnect and reconnect while the smoke resource runs',
  })
end, false)
