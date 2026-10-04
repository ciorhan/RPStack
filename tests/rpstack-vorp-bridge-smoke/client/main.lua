-- rpstack-vorp-bridge-smoke client probes.
-- Reacts only to smoke events sent by the server, which registers its commands
-- only when rpstack:smoke:enabled is 1. Uses smoke-owned keys and events only.

-- A3: attempt a client-side write to this player's own state bag.
RegisterNetEvent('rpstack:vorpsmoke:net:stateProbe', function(token)
  if type(token) ~= 'string' or #token > 64 then return end
  LocalPlayer.state:set('rpstackSmokeProbe', token, true)
  TriggerServerEvent('rpstack:vorpsmoke:net:stateProbeAck', token)
end)
