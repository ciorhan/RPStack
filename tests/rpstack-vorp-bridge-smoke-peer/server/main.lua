if GetConvarInt('rpstack:smoke:enabled', 0) ~= 1 then
  print('[rpstack-vorp-bridge-smoke-peer] disabled')
  return
end

local SMOKE_RESOURCE = 'rpstack-vorp-bridge-smoke'
local PEER_RESULT = 'rpstack:vorpsmoke:peerResult'

-- A4: report whether the smoke resource's CancelEvent was visible here.
local function report(eventName, token)
  if type(token) ~= 'string' then return end
  TriggerEvent(PEER_RESULT, {
    event = eventName,
    token = token,
    sawCanceled = WasEventCanceled(),
  })
end

AddEventHandler('rpstack:vorpsmoke:cancelProbeLocal', function(token)
  report('rpstack:vorpsmoke:cancelProbeLocal', token)
end)

RegisterNetEvent('rpstack:vorpsmoke:net:cancelProbe', function(token)
  report('rpstack:vorpsmoke:net:cancelProbe', token)
end)

-- A5: tick counter read by the smoke resource through an export.
local tick = 0
CreateThread(function()
  while true do
    tick = tick + 1
    Wait(0)
  end
end)

exports('getTick', function()
  return tick
end)

print(('[rpstack-vorp-bridge-smoke-peer] enabled (peer of %s)'):format(SMOKE_RESOURCE))
