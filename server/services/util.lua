Util = {}

function Util.safe_tostring(v)
  local ok, res = pcall(function() return tostring(v) end)
  return ok and res or '<tostring_error>'
end

function Util.ms()
  -- Citizen timer in ms
  return GetGameTimer()
end