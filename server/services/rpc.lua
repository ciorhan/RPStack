RPC = {
  handlers = {},
}

-- Server-side register
function RPC.register(name, fn)
  if RPC.handlers[name] then
    error('RPC handler already registered: ' .. name)
  end
  RPC.handlers[name] = fn
end

-- Net endpoint: client calls rp:rpc:req with name + payload, server replies to rp:rpc:res
RegisterNetEvent('rp:rpc:req', function(reqId, name, payload)
  local source = source
  local route = 'rpc:' .. tostring(name)

  local okRate = RateLimit.check(source, route)
  if not okRate then
    Log.warn('rpc_rate_limited', { source = source, name = name })
    TriggerClientEvent('rp:rpc:res', source, reqId, false, { error = 'rate_limited' })
    return
  end

  local handler = RPC.handlers[name]
  if not handler then
    TriggerClientEvent('rp:rpc:res', source, reqId, false, { error = 'not_found' })
    return
  end

  local p = PlayerRegistry.get(source)
  if not p then
    TriggerClientEvent('rp:rpc:res', source, reqId, false, { error = 'not_ready' })
    return
  end

  local start = Util.ms()
  local ok, result = pcall(handler, p, payload)
  local dur = Util.ms() - start

  if dur > 50 then
    Log.warn('rpc_slow', { name = name, ms = dur, source = source })
  end

  if not ok then
    Log.error('rpc_error', { name = name, err = Util.safe_tostring(result), source = source })
    TriggerClientEvent('rp:rpc:res', source, reqId, false, { error = 'internal' })
    return
  end

  TriggerClientEvent('rp:rpc:res', source, reqId, true, result)
end)