Log = {}

local function now()
  return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function fmt_ctx(ctx)
  if not ctx then return '' end
  local parts = {}
  for k,v in pairs(ctx) do
    parts[#parts+1] = tostring(k) .. '=' .. tostring(v)
  end
  table.sort(parts)
  return ' {' .. table.concat(parts, ' ') .. '}'
end

function Log.info(msg, ctx)
  print(('[%s] [INFO] %s%s'):format(now(), msg, fmt_ctx(ctx)))
end

function Log.warn(msg, ctx)
  print(('[%s] [WARN] %s%s'):format(now(), msg, fmt_ctx(ctx)))
end

function Log.error(msg, ctx)
  print(('[%s] [ERROR] %s%s'):format(now(), msg, fmt_ctx(ctx)))
end