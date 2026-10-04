if not RPSTACK_VSMOKE_ENABLED then return end

-- Verifies the [inferred] runtime assumptions from docs/integration/vorp-analysis.md
-- ("Recommended first implementation step"). Money checks use $1 and always restore it.
-- Run them only against the tester's own character.

-- ── A1: fresh getUsedCharacter across the export boundary ─────────────────────

RegisterCommand('rpstack_vorp_assume1', function(source, args)
  if not VSMOKE.consoleOnly(source) then return end
  local src = VSMOKE.playerArg(args, 'rpstack_vorp_assume1 <playerSource>')
  if not src then return end

  local snapshot = VSMOKE.vorpCharacter(src)
  if not snapshot then
    VSMOKE.report('A1 fresh getUsedCharacter', false, { error = 'no active VORP character' })
    return
  end

  local m0 = snapshot.money
  snapshot.addCurrency(0, 1)
  local fresh = VSMOKE.vorpCharacter(src)
  local freshMoney = fresh and fresh.money or nil
  local staleMoney = snapshot.money

  if fresh then fresh.removeCurrency(0, 1) end
  local restoredMoney = (VSMOKE.vorpCharacter(src) or {}).money

  VSMOKE.report('A1 fresh getUsedCharacter reflects current values',
    VSMOKE.moneyEquals(freshMoney, m0 + 1) and VSMOKE.moneyEquals(restoredMoney, m0), {
      before = m0,
      freshAfterAdd = freshMoney,
      staleSnapshotAfterAdd = staleMoney,
      restored = restoredMoney,
      note = 'staleSnapshotAfterAdd equal to before means snapshots must not be cached',
    })
end, false)

-- ── A2: getUsers()[steamId].SaveUser() from another resource ───────────────────

local function saveUser(src)
  local steamId = GetPlayerIdentifierByType(src, 'steam')
  if not steamId then return false, 'no steam identifier' end
  local users = VSMOKE.core().getUsers()
  local entry = type(users) == 'table' and users[steamId] or nil
  if type(entry) ~= 'table' or entry.SaveUser == nil then
    return false, 'getUsers entry or SaveUser missing'
  end
  local ok, err = pcall(entry.SaveUser)
  if not ok then return false, tostring(err) end
  return true, nil
end

RegisterCommand('rpstack_vorp_assume2', function(source, args)
  if not VSMOKE.consoleOnly(source) then return end
  local src = VSMOKE.playerArg(args, 'rpstack_vorp_assume2 <playerSource>')
  if not src then return end

  CreateThread(function()
    local character = VSMOKE.vorpCharacter(src)
    if not character then
      VSMOKE.report('A2 SaveUser cross-resource', false, { error = 'no active VORP character' })
      return
    end
    local characterId = tonumber(character.charIdentifier)
    local m0 = character.money

    local dbBefore
    VSMOKE.readCharacterMoney(characterId, function(v) dbBefore = v end)
    Wait(1000)

    character.addCurrency(0, 1)
    local saved, saveErr = saveUser(src)
    Wait(1500)
    local dbAfterSave
    VSMOKE.readCharacterMoney(characterId, function(v) dbAfterSave = v end)
    Wait(1000)

    local current = VSMOKE.vorpCharacter(src)
    if current then current.removeCurrency(0, 1) end
    local restoreSaved, restoreErr = saveUser(src)
    Wait(1500)
    local dbAfterRestore
    VSMOKE.readCharacterMoney(characterId, function(v) dbAfterRestore = v end)
    Wait(1000)
    local memoryAfterRestore = (VSMOKE.vorpCharacter(src) or {}).money

    VSMOKE.report('A2 SaveUser callable from another resource and persists',
      saved and VSMOKE.moneyEquals(dbAfterSave, m0 + 1)
        and restoreSaved and VSMOKE.moneyEquals(dbAfterRestore, m0)
        and VSMOKE.moneyEquals(memoryAfterRestore, m0), {
        characterId = characterId,
        memoryBefore = m0,
        dbBefore = dbBefore,
        saveCallable = saved,
        saveError = saveErr,
        dbAfterSave = dbAfterSave,
        restoreSaveCallable = restoreSaved,
        restoreError = restoreErr,
        dbAfterRestore = dbAfterRestore,
        memoryAfterRestore = memoryAfterRestore,
      })
  end)
end, false)

-- ── A3: client writes to its own Player(src).state ─────────────────────────────

local stateProbe = { pending = nil, acked = false, handlerSaw = nil }

AddStateBagChangeHandler(VSMOKE.STATE_PROBE_KEY, nil, function(bagName, _, value)
  if stateProbe.pending and value == stateProbe.pending then
    stateProbe.handlerSaw = bagName
  end
end)

RegisterNetEvent('rpstack:vorpsmoke:net:stateProbeAck', function(token)
  local src = source
  if stateProbe.pending and stateProbe.src == src and token == stateProbe.pending then
    stateProbe.acked = true
  end
end)

RegisterCommand('rpstack_vorp_assume3', function(source, args)
  if not VSMOKE.consoleOnly(source) then return end
  local src = VSMOKE.playerArg(args, 'rpstack_vorp_assume3 <playerSource>')
  if not src then return end

  CreateThread(function()
    local token = ('probe-%d-%d'):format(os.time(), math.random(100000, 999999))
    Player(src).state:set(VSMOKE.STATE_PROBE_KEY, nil, true)
    stateProbe.pending, stateProbe.src, stateProbe.acked, stateProbe.handlerSaw = token, src, false, nil

    TriggerClientEvent(VSMOKE.NET_STATE_PROBE, src, token)
    Wait(3000)

    local serverValue = Player(src).state[VSMOKE.STATE_PROBE_KEY]
    local accepted = serverValue == token
    local evidence = {
      token = token,
      clientAcked = stateProbe.acked,
      serverValue = serverValue,
      changeHandlerBag = stateProbe.handlerSaw,
      clientWriteAccepted = accepted,
    }

    Player(src).state:set(VSMOKE.STATE_PROBE_KEY, nil, true)
    stateProbe.pending = nil

    if not stateProbe.acked then
      VSMOKE.report('A3 client state bag write determined', false, evidence)
      return
    end
    VSMOKE.report('A3 client state bag write determined', true, evidence)
    VSMOKE.info('A3', accepted and 'FINDING: client writes to own player state ARE accepted'
      or 'FINDING: client writes to own player state are NOT accepted', {})
  end)
end, false)

-- ── A4: CancelEvent in one resource vs another resource's handler ─────────────

local cancelProbe = { token = nil, src = nil, smokeRan = {}, peer = {} }

local function smokeCancelHandler(eventName, token, src)
  if token ~= cancelProbe.token then return end
  if src and src ~= cancelProbe.src then return end
  cancelProbe.smokeRan[eventName] = true
  CancelEvent()
end

AddEventHandler(VSMOKE.LOCAL_CANCEL_PROBE, function(token)
  smokeCancelHandler(VSMOKE.LOCAL_CANCEL_PROBE, token, nil)
end)

RegisterNetEvent(VSMOKE.NET_CANCEL_PROBE, function(token)
  local src = source
  smokeCancelHandler(VSMOKE.NET_CANCEL_PROBE, token, src)
end)

AddEventHandler(VSMOKE.PEER_RESULT, function(result)
  if GetInvokingResource() ~= VSMOKE.PEER_RESOURCE then return end
  if type(result) ~= 'table' or result.token ~= cancelProbe.token then return end
  cancelProbe.peer[result.event] = { ran = true, sawCanceled = result.sawCanceled == true }
end)

local function evaluateCancel(eventName)
  local smokeRan = cancelProbe.smokeRan[eventName] == true
  local peer = cancelProbe.peer[eventName]
  local finding, determined
  if not smokeRan then
    finding, determined = 'smoke handler did not run', false
  elseif not peer then
    finding, determined = 'CancelEvent STOPPED the other resource handler', true
  elseif peer.sawCanceled then
    finding, determined = 'CancelEvent did NOT stop the other resource handler (it ran and saw WasEventCanceled=true)', true
  else
    finding, determined = 'peer ran before the cancelling handler; order inconclusive', false
  end
  VSMOKE.report('A4 CancelEvent cross-resource determined (' .. eventName .. ')', determined, {
    smokeRan = smokeRan, peer = peer, finding = finding,
  })
end

RegisterCommand('rpstack_vorp_assume4', function(source, args)
  if not VSMOKE.consoleOnly(source) then return end
  local src = VSMOKE.playerArg(args, 'rpstack_vorp_assume4 <playerSource>')
  if not src then return end

  if GetResourceState(VSMOKE.PEER_RESOURCE) ~= 'started' then
    VSMOKE.report('A4 CancelEvent cross-resource', false, { error = VSMOKE.PEER_RESOURCE .. ' is not started' })
    return
  end

  CreateThread(function()
    cancelProbe.token = ('cancel-%d-%d'):format(os.time(), math.random(100000, 999999))
    cancelProbe.src = src
    cancelProbe.smokeRan, cancelProbe.peer = {}, {}

    TriggerEvent(VSMOKE.LOCAL_CANCEL_PROBE, cancelProbe.token)
    TriggerClientEvent(VSMOKE.NET_FIRE_CANCEL, src, cancelProbe.token)
    Wait(3000)

    evaluateCancel(VSMOKE.LOCAL_CANCEL_PROBE)
    evaluateCancel(VSMOKE.NET_CANCEL_PROBE)
    cancelProbe.token = nil
  end)
end, false)

-- ── A5: same-tick check-then-removeCurrency interleaving ──────────────────────
-- Method: a local ticker thread and the peer resource's ticker thread each
-- increment a counter once per server tick. The check runs N iterations of
-- "read fresh money, check, removeCurrency(0, 1), re-read, addCurrency(0, 1)"
-- with no Wait. If either counter changes during the section, another handler
-- ran in the middle. Money is restored by the matching addCurrency calls.

local ITERATIONS = 100

RegisterCommand('rpstack_vorp_assume5', function(source, args)
  if not VSMOKE.consoleOnly(source) then return end
  local src = VSMOKE.playerArg(args, 'rpstack_vorp_assume5 <playerSource>')
  if not src then return end

  if GetResourceState(VSMOKE.PEER_RESOURCE) ~= 'started' then
    VSMOKE.report('A5 same-tick interleaving', false, { error = VSMOKE.PEER_RESOURCE .. ' is not started' })
    return
  end

  CreateThread(function()
    local start = VSMOKE.vorpCharacter(src)
    if not start or type(start.money) ~= 'number' or start.money < 1 then
      VSMOKE.report('A5 same-tick interleaving', false, { error = 'needs an active character with at least $1' })
      return
    end
    local m0 = start.money

    local ticking, localTick = true, 0
    CreateThread(function()
      while ticking do
        localTick = localTick + 1
        Wait(0)
      end
    end)
    Wait(200)

    local peer = exports[VSMOKE.PEER_RESOURCE]
    local l0, p0, t0 = localTick, peer:getTick(), GetGameTimer()
    local mismatches = 0

    for _ = 1, ITERATIONS do
      local character = VSMOKE.vorpCharacter(src)
      local money = character.money
      if money >= 1 then
        character.removeCurrency(0, 1)
        local after = VSMOKE.vorpCharacter(src).money
        if not VSMOKE.moneyEquals(after, money - 1) then mismatches = mismatches + 1 end
        VSMOKE.vorpCharacter(src).addCurrency(0, 1)
      else
        mismatches = mismatches + 1
      end
    end

    local l1, p1, t1 = localTick, peer:getTick(), GetGameTimer()
    ticking = false

    local final = (VSMOKE.vorpCharacter(src) or {}).money
    local interleaved = l1 ~= l0 or p1 ~= p0

    VSMOKE.report('A5 check-then-removeCurrency does not interleave',
      not interleaved and mismatches == 0 and VSMOKE.moneyEquals(final, m0), {
        iterations = ITERATIONS,
        localTicks = { before = l0, after = l1 },
        peerTicks = { before = p0, after = p1 },
        elapsedMs = t1 - t0,
        mismatches = mismatches,
        moneyBefore = m0,
        moneyAfter = final,
      })
  end)
end, false)
