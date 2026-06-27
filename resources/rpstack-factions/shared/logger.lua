local levels = { debug = 10, info = 20, warn = 30, error = 40 }

local function now()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function levelValue(lvl)
  return levels[lvl] or 20
end

local function shouldLog(lvl)
  local configured = (RPSTACK_CONFIG and RPSTACK_CONFIG.logLevel) or 'info'
  return levelValue(lvl) >= levelValue(configured)
end

RPSTACK_LOG = {}

function RPSTACK_LOG.log(lvl, category, message, fields)
  if not shouldLog(lvl) then return end
  category = category or "core"
  fields = fields or {}

  local parts = {}
  for k, v in pairs(fields) do
    parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
  end

  local extra = ""
  if #parts > 0 then extra = " " .. table.concat(parts, " ") end

  print(("[RPStack] %s %-5s [%s] %s%s"):format(now(), lvl, category, message, extra))
end

function RPSTACK_LOG.debug(cat, msg, fields) RPSTACK_LOG.log("debug", cat, msg, fields) end
function RPSTACK_LOG.info(cat, msg, fields)  RPSTACK_LOG.log("info",  cat, msg, fields) end
function RPSTACK_LOG.warn(cat, msg, fields)  RPSTACK_LOG.log("warn",  cat, msg, fields) end
function RPSTACK_LOG.error(cat, msg, fields) RPSTACK_LOG.log("error", cat, msg, fields) end