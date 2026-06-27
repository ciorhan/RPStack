if GetConvarInt('rpstack:smoke:enabled', 0) ~= 1 then
  print('[rpstack-factions-smoke] disabled')
  return
end

local function printResult(stage, result)
  print(('[SMOKE] %s: %s'):format(stage, json.encode(result or {})))
  return result and result.ok == true
end

RegisterCommand('rpstack_identity_smoke', function(source, args)
  if source ~= 0 then
    print('[SMOKE] Run this command from the FXServer console.')
    return
  end

  local playerSource = tonumber(args[1])
  if not playerSource or playerSource <= 0 then
    print('[SMOKE] Usage: rpstack_identity_smoke <playerSource>')
    return
  end

  local identity = exports['rpstack-identity']

  local function selectCharacter(character)
    identity['rpstack:identity:selectCharacter'](
      identity,
      playerSource,
      character.id,
      function(selected)
        if not printResult('selectCharacter', selected) then return end
        print(('[SMOKE] IDENTITY PASS playerSource=%d characterId=%d'):format(
          playerSource,
          selected.character.id
        ))
      end
    )
  end

  identity['rpstack:identity:getCharacters'](
    identity,
    playerSource,
    function(result)
      if not printResult('getCharacters', result) then return end
      if result.characters[1] then
        selectCharacter(result.characters[1])
        return
      end

      identity['rpstack:identity:createCharacter'](
        identity,
        playerSource,
        { firstName = 'Smoke', lastName = 'Tester' },
        function(created)
          if not printResult('createCharacter', created) then return end
          selectCharacter(created.character)
        end
      )
    end
  )
end, false)

RegisterCommand('rpstack_factions_smoke', function(source, args)
  if source ~= 0 then
    print('[SMOKE] Run this command from the FXServer console.')
    return
  end

  local characterId = tonumber(args[1])
  if not characterId or characterId <= 0 or characterId ~= math.floor(characterId) then
    print('[SMOKE] Usage: rpstack_factions_smoke <characterId>')
    return
  end

  print(('[SMOKE] starting with characterId=%d'):format(characterId))

  local suffix = os.time() % 1000000
  local factions = exports['rpstack-factions']
  local economy = exports['rpstack-economy']

  factions:createFaction({
    name = ('Smoke Test %06d'):format(suffix),
    tag = ('T%06d'):format(suffix),
    type = 'guild',
    founderCharId = characterId,
  }, function(created)
    if not printResult('createFaction', created) then return end
    local factionId = created.faction.id

    economy['rpstack:economy:adjustCashByCharId'](
      economy,
      characterId,
      500,
      'factions_smoke_funding',
      function(funded)
        if not printResult('fundCharacter', funded) then return end

        factions:depositToTreasury(
          factionId,
          characterId,
          200,
          'smoke deposit',
          function(deposited)
            if not printResult('deposit', deposited) then return end

            factions:withdrawFromTreasury(
              factionId,
              characterId,
              75,
              'smoke withdrawal',
              function(withdrawn)
                if not printResult('withdraw', withdrawn) then return end

                factions:getTreasuryBalance(factionId, function(balance)
                  if not printResult('balance', balance) then return end

                  SetTimeout(500, function()
                    factions:getTreasuryLedger(factionId, 10, function(ledger)
                      if not printResult('ledger', ledger) then return end
                      if balance.cash ~= 125 or #ledger.entries < 2 then
                        print('[SMOKE] FAIL: unexpected balance or missing audit entries')
                        return
                      end

                      factions:depositToTreasury(
                        factionId,
                        characterId,
                        1000000,
                        'expected insufficient funds',
                        function(rejected)
                          if rejected and rejected.ok then
                            print('[SMOKE] FAIL: insufficient-funds deposit succeeded')
                            return
                          end

                          print(('[SMOKE] PASS factionId=%d treasury=%d ledgerEntries=%d'):format(
                            factionId,
                            balance.cash,
                            #ledger.entries
                          ))
                        end
                      )
                    end)
                  end)
                end)
              end
            )
          end
        )
      end
    )
  end)
end, false)

print('[rpstack-factions-smoke] ready: rpstack_factions_smoke <characterId>')

RegisterCommand('rpstack_factions_relationship_smoke', function(source, args)
  if source ~= 0 then
    print('[SMOKE] Run this command from the FXServer console.')
    return
  end

  local characterId = tonumber(args[1])
  local firstFactionId = tonumber(args[2])
  if not characterId or not firstFactionId then
    print('[SMOKE] Usage: rpstack_factions_relationship_smoke <characterId> <factionId>')
    return
  end

  local suffix = os.time() % 1000000
  local factions = exports['rpstack-factions']
  factions:createFaction({
    name = ('Relationship Test %06d'):format(suffix),
    tag = ('R%06d'):format(suffix),
    type = 'guild',
    founderCharId = characterId,
  }, function(created)
    if not printResult('createRelationshipFaction', created) then return end
    local secondFactionId = created.faction.id

    factions:setRelationship(
      firstFactionId,
      secondFactionId,
      'hostile',
      characterId,
      function(updated)
        if not printResult('setRelationship', updated) then return end

        local forward = factions:getRelationship(firstFactionId, secondFactionId)
        local reverse = factions:getRelationship(secondFactionId, firstFactionId)
        if not forward.ok
          or not reverse.ok
          or forward.status ~= 'hostile'
          or reverse.status ~= 'hostile'
        then
          print('[SMOKE] FAIL: relationship is not symmetric')
          return
        end

        print(('[SMOKE] PASS relationship factionId=%d secondFactionId=%d'):format(
          firstFactionId,
          secondFactionId
        ))
      end
    )
  end)
end, false)
