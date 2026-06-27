-- db.lua
-- Thin wrapper around oxmysql. All DB access in RPStack goes through these functions.
-- Never call MySQL.* directly outside this file.

RPSTACK_DB = {}

-- Execute a query that returns rows (SELECT).
-- cb(rows) called with result array, or empty table on error.
function RPSTACK_DB.query(sql, params, cb)
  local start = GetGameTimer()
  MySQL.query(sql, params, function(rows)
    local dur = GetGameTimer() - start
    if dur > RPSTACK_PERSISTENCE_CONFIG.slowQueryMs then
      RPSTACK_LOG.warn("persistence", "slow query", { ms = dur, sql = sql })
    end
    cb(rows or {})
  end)
end

-- Execute a query that returns a single row.
-- cb(row) called with first row or nil.
function RPSTACK_DB.single(sql, params, cb)
  RPSTACK_DB.query(sql, params, function(rows)
    cb(rows[1])
  end)
end

-- Execute an INSERT/UPDATE/DELETE.
-- cb(affectedRows) called with number of affected rows.
function RPSTACK_DB.execute(sql, params, cb)
  local start = GetGameTimer()
  MySQL.update(sql, params, function(affected)
    local dur = GetGameTimer() - start
    if dur > RPSTACK_PERSISTENCE_CONFIG.slowQueryMs then
      RPSTACK_LOG.warn("persistence", "slow execute", { ms = dur, sql = sql })
    end
    cb(affected or 0)
  end)
end

-- Execute an INSERT and return the new row id.
-- cb(insertId) called with the auto-increment id or nil on failure.
function RPSTACK_DB.insert(sql, params, cb)
  local start = GetGameTimer()
  MySQL.insert(sql, params, function(insertId)
    local dur = GetGameTimer() - start
    if dur > RPSTACK_PERSISTENCE_CONFIG.slowQueryMs then
      RPSTACK_LOG.warn("persistence", "slow insert", { ms = dur, sql = sql })
    end
    cb(insertId)
  end)
end

-- Check database connectivity. cb(ok, err) 
function RPSTACK_DB.ping(cb)
  RPSTACK_DB.query("SELECT 1 AS ok", {}, function(rows)
    if rows and rows[1] then
      cb(true, nil)
    else
      cb(false, "no response from database")
    end
  end)
end