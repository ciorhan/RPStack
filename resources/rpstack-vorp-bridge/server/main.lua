-- rpstack-vorp-bridge/server/main.lua
-- No migrations: the bridge owns no tables yet.
-- No net events and no client scripts: VORP is reached only through server APIs.

local function startBridge()
  if RPSTACK_BRIDGE_STATE.started then return end
  RPSTACK_BRIDGE_STATE.started = true

  CreateThread(function()
    Wait(0)
    RPSTACK_LOG.info("vorp-bridge", "starting")

    AddEventHandler(BRIDGE_VORP.EVENT_SELECTED_CHARACTER, function(src, payload)
      RPSTACK_BRIDGE_IDENTITY.onSelectedCharacter(GetInvokingResource(), src, payload)
    end)

    AddEventHandler('playerDropped', function()
      local src = source
      RPSTACK_BRIDGE_IDENTITY.onPlayerDropped(src)
    end)

    local restored = RPSTACK_BRIDGE_IDENTITY.rebuild()

    RPSTACK_LOG.info("vorp-bridge", "ready", { activeCharacters = restored })
    TriggerEvent(BRIDGE_EVENTS.READY)
  end)
end

AddEventHandler('rpstack:persistence:ready', startBridge)

-- Catch-up when the bridge starts after persistence (resource restart).
CreateThread(function()
  Wait(0)
  local ok, ready = pcall(function()
    return exports['rpstack-persistence']:isPersistenceReady()
  end)
  if ok and ready then startBridge() end
end)
