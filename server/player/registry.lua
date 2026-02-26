PlayerRegistry = {
  bySource = {},
}

local function primaryId(ids)
  return ids.license2 or ids.license or ids.fivem or ids.steam or ('src:' .. tostring(source))
end

function PlayerRegistry.add(source)
  local ids = Identifiers.get(source)
  local pid = primaryId(ids)

  PlayerRegistry.bySource[source] = {
    source = source,
    pid = pid,
    name = GetPlayerName(source) or ('player:' .. tostring(source)),
    identifiers = ids,
    connectedAt = os.time(),
  }

  Log.info('player_connected', { source = source, pid = pid })
  return PlayerRegistry.bySource[source]
end

function PlayerRegistry.remove(source)
  local p = PlayerRegistry.bySource[source]
  if p then
    Log.info('player_disconnected', { source = source, pid = p.pid })
  end
  PlayerRegistry.bySource[source] = nil
end

function PlayerRegistry.get(source)
  return PlayerRegistry.bySource[source]
end