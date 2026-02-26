local pending = {}
local seq = 0

RegisterNetEvent('rp:rpc:res', function(reqId, ok, data)
  local cb = pending[reqId]
  if cb then
    pending[reqId] = nil
    cb(ok, data)
  end
end)

local function rpcCall(name, payload, cb)
  seq = seq + 1
  local reqId = tostring(GetGameTimer()) .. ':' .. tostring(seq)
  pending[reqId] = cb
  TriggerServerEvent('rp:rpc:req', reqId, name, payload)
end

RegisterCommand('rpcping', function()
  rpcCall('core.ping', { hello = 'world' }, function(ok, data)
    if ok then
      print(('RPC OK: %s'):format(json.encode(data)))
    else
      print(('RPC FAIL: %s'):format(json.encode(data)))
    end
  end)
end)