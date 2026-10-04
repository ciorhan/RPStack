if GetConvarInt('rpstack:smoke:enabled', 0) ~= 1 then
  print('[rpstack-vorp-bridge-smoke-peer] disabled')
  return
end

local SMOKE_RESOURCE = 'rpstack-vorp-bridge-smoke'

-- A5: tick counter read by the smoke resource through an export.
-- (The A4 CancelEvent handlers were removed when A4 was retired; see ADR-008.)
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
