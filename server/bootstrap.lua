AddEventHandler('playerJoining', function()
  local src = source
  PlayerRegistry.add(src)
end)

AddEventHandler('playerDropped', function()
  local src = source
  PlayerRegistry.remove(src)
end)