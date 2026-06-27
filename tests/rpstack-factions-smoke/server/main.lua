if GetConvarInt('rpstack:smoke:enabled', 0) ~= 1 then
  print('[rpstack-factions-smoke] disabled')
  return
end

local function printResult(stage, result)
  print(('[SMOKE] %s: %s'):format(stage, json.encode(result or {})))
  return result and result.ok == true
end

local function isPositiveInteger(value)
  return type(value) == 'number' and value > 0 and value == math.floor(value)
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
  if not isPositiveInteger(characterId) then
    print('[SMOKE] Usage: rpstack_factions_smoke <characterId>')
    return
  end

  print(('[SMOKE] starting with characterId=%d'):format(characterId))

  local createCompleted = false
  SetTimeout(5000, function()
    if not createCompleted then
      print('[SMOKE] TIMEOUT: createFaction callback did not complete')
    end
  end)

  local suffix = os.time() % 1000000
  local factions = exports['rpstack-factions']
  local economy = exports['rpstack-economy']

  factions['createFaction'](factions, {
    name = ('Smoke Test %06d'):format(suffix),
    tag = ('T%06d'):format(suffix),
    type = 'guild',
    founderCharId = characterId,
  }, function(created)
    createCompleted = true
    if not printResult('createFaction', created) then return end
    local factionId = created.faction.id

    economy['rpstack:economy:adjustCashByCharId'](
      economy,
      characterId,
      500,
      'factions_smoke_funding',
      function(funded)
        if not printResult('fundCharacter', funded) then return end

        factions['depositToTreasury'](
          factions,
          factionId,
          characterId,
          200,
          'smoke deposit',
          function(deposited)
            if not printResult('deposit', deposited) then return end

            factions['withdrawFromTreasury'](
              factions,
              factionId,
              characterId,
              75,
              'smoke withdrawal',
              function(withdrawn)
                if not printResult('withdraw', withdrawn) then return end

                factions['getTreasuryBalance'](factions, factionId, function(balance)
                  if not printResult('balance', balance) then return end

                  SetTimeout(500, function()
                    factions['getTreasuryLedger'](factions, factionId, 10, function(ledger)
                      if not printResult('ledger', ledger) then return end
                      if balance.cash ~= 125 or #ledger.entries < 2 then
                        print('[SMOKE] FAIL: unexpected balance or missing audit entries')
                        return
                      end

                      factions['depositToTreasury'](
                        factions,
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

print('[rpstack-factions-smoke] ready: rpstack_identity_smoke <playerSource>')
print('[rpstack-factions-smoke] ready: rpstack_factions_smoke <characterId>')
print('[rpstack-factions-smoke] ready: rpstack_factions_state_smoke <characterId> <factionAId> <factionBId>')
print('[rpstack-factions-smoke] ready: rpstack_economy_callbacks_smoke <playerSource>')

RegisterCommand('rpstack_factions_state_smoke', function(source, args)
  local completed = false
  local function finish(passed, details)
    if completed then return end
    completed = true
    print(('[SMOKE] %s state: %s'):format(
      passed and 'PASS' or 'FAIL',
      json.encode(details or {})
    ))
  end

  if source ~= 0 then
    finish(false, { error = 'console_only' })
    return
  end

  local characterId = tonumber(args[1])
  local factionAId = tonumber(args[2])
  local factionBId = tonumber(args[3])
  if not isPositiveInteger(characterId)
    or not isPositiveInteger(factionAId)
    or not isPositiveInteger(factionBId)
    or factionAId == factionBId
    or args[4] ~= nil
  then
    finish(false, {
      error = 'usage: rpstack_factions_state_smoke <characterId> <factionAId> <factionBId>',
    })
    return
  end

  local factions = exports['rpstack-factions']
  local ok, forward, reverse, roster = pcall(function()
    return factions['getRelationship'](factions, factionAId, factionBId),
      factions['getRelationship'](factions, factionBId, factionAId),
      factions['getOnlineRoster'](factions, factionAId)
  end)
  if not ok then
    finish(false, { error = tostring(forward) })
    return
  end

  local characterOnline = false
  if roster and roster.ok and type(roster.roster) == 'table' then
    for _, member in ipairs(roster.roster) do
      if member.characterId == characterId then
        characterOnline = true
        break
      end
    end
  end

  SetTimeout(5000, function()
    finish(false, { error = 'treasury_callback_timeout' })
  end)

  local invoked, invokeError = pcall(function()
    factions['getTreasuryBalance'](factions, factionAId, function(balance)
      local forwardHostile = forward
        and forward.ok == true
        and forward.status == 'hostile'
      local reverseHostile = reverse
        and reverse.ok == true
        and reverse.status == 'hostile'
      local treasuryReadable = balance
        and balance.ok == true
        and type(balance.cash) == 'number'
        and type(balance.bank) == 'number'

      finish(
        forwardHostile
          and reverseHostile
          and characterOnline
          and treasuryReadable,
        {
          forwardHostile = forwardHostile,
          reverseHostile = reverseHostile,
          characterOnline = characterOnline,
          treasuryReadable = treasuryReadable,
        }
      )
    end)
  end)
  if not invoked then
    finish(false, { error = tostring(invokeError) })
  end
end, false)

RegisterCommand('rpstack_economy_callbacks_smoke', function(source, args)
  if source ~= 0 then
    print('[SMOKE] FAIL economy callbacks: console_only')
    return
  end

  local playerSource = tonumber(args[1])
  if not isPositiveInteger(playerSource) then
    print('[SMOKE] FAIL economy callbacks: usage')
    return
  end

  local economy = exports['rpstack-economy']
  local tests = {
    {
      name = 'getBalance',
      expectOk = true,
      invoke = function(cb)
        economy['rpstack:economy:getBalance'](economy, playerSource, cb)
      end,
    },
    {
      name = 'addMoney',
      expectOk = false,
      invoke = function(cb)
        economy['rpstack:economy:addMoney'](economy, playerSource, 'cash', 0, 'callback_smoke', cb)
      end,
    },
    {
      name = 'removeMoney',
      expectOk = false,
      invoke = function(cb)
        economy['rpstack:economy:removeMoney'](economy, playerSource, 'cash', 0, 'callback_smoke', cb)
      end,
    },
    {
      name = 'deposit',
      expectOk = false,
      invoke = function(cb)
        economy['rpstack:economy:deposit'](economy, playerSource, 0, 'callback_smoke', cb)
      end,
    },
    {
      name = 'withdraw',
      expectOk = false,
      invoke = function(cb)
        economy['rpstack:economy:withdraw'](economy, playerSource, 0, 'callback_smoke', cb)
      end,
    },
  }

  local completed = false
  local index = 1
  local function finish(passed, detail)
    if completed then return end
    completed = true
    print(('[SMOKE] %s economy callbacks: %s'):format(
      passed and 'PASS' or 'FAIL',
      detail
    ))
  end

  local runNext
  runNext = function()
    local test = tests[index]
    if not test then
      finish(true, ('callbacks=%d'):format(#tests))
      return
    end
    test.invoke(function(result)
      if not result or result.ok ~= test.expectOk then
        finish(false, ('%s result=%s'):format(test.name, json.encode(result or {})))
        return
      end
      index = index + 1
      runNext()
    end)
  end

  SetTimeout(5000, function()
    finish(false, ('callback_timeout index=%d'):format(index))
  end)
  runNext()
end, false)

RegisterCommand('rpstack_factions_relationship_smoke', function(source, args)
  if source ~= 0 then
    print('[SMOKE] Run this command from the FXServer console.')
    return
  end

  local characterId = tonumber(args[1])
  local firstFactionId = tonumber(args[2])
  local existingSecondFactionId = tonumber(args[3])
  if not isPositiveInteger(characterId)
    or not isPositiveInteger(firstFactionId)
    or (args[3] ~= nil and not isPositiveInteger(existingSecondFactionId))
    or existingSecondFactionId == firstFactionId
  then
    print('[SMOKE] Usage: rpstack_factions_relationship_smoke <characterId> <factionId> [secondFactionId]')
    return
  end

  local factions = exports['rpstack-factions']
  local function testRelationship(secondFactionId)
    factions['setRelationship'](
      factions,
      firstFactionId,
      secondFactionId,
      'hostile',
      characterId,
      function(updated)
        if not printResult('setRelationship', updated) then return end

        local forward = factions['getRelationship'](factions, firstFactionId, secondFactionId)
        local reverse = factions['getRelationship'](factions, secondFactionId, firstFactionId)
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
  end

  if existingSecondFactionId then
    testRelationship(existingSecondFactionId)
    return
  end

  local suffix = os.time() % 1000000
  factions['createFaction'](factions, {
    name = ('Relationship Test %06d'):format(suffix),
    tag = ('R%06d'):format(suffix),
    type = 'guild',
    founderCharId = characterId,
  }, function(created)
    if not printResult('createRelationshipFaction', created) then return end
    testRelationship(created.faction.id)
  end)
end, false)
