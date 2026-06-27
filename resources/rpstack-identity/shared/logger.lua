-- Local logger for resources that can't access rpstack-core's RPSTACK_LOG global.
-- Matches the same output format as core's logger.

local levels = { debug = 10, info = 20, warn = 30, error = 40 }

local function now()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function levelValue(lvl)
  return levels[lvl] or 20
end

RPSTACK_LOG = RPSTACK_LOG or {}

local function log(lvl, category, message, fields)
  fields = fields or {}
  local parts = {}
  for k, v in pairs(fields) do
    parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
  end
  local extra = #parts > 0 and (" " .. table.concat(parts, " ")) or ""
  print(("[RPStack] %s %-5s [%s] %s%s"):format(now(), lvl, category, message, extra))
end

function RPSTACK_LOG.debug(cat, msg, fields) log("debug", cat, msg, fields) end
function RPSTACK_LOG.info(cat, msg, fields)  log("info",  cat, msg, fields) end
function RPSTACK_LOG.warn(cat, msg, fields)  log("warn",  cat, msg, fields) end
function RPSTACK_LOG.error(cat, msg, fields) log("error", cat, msg, fields) end