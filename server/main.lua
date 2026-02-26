Core = {}

function Core.GetPlayer(source)
  return PlayerRegistry.get(source)
end

function Core.Log()
  return Log
end

function Core.RPC()
  return RPC
end

exports('GetCore', function()
  return Core
end)

-- Example RPC (proves the pipeline)
RPC.register('core.ping', function(player, payload)
  return {
    pong = true,
    serverTime = os.time(),
    player = { pid = player.pid, name = player.name },
    payload = payload,
  }
end)

Log.info('rp_core_started', { version = '0.0.1' })