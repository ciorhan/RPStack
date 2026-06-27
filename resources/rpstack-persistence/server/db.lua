RPSTACK_DB = {}

function RPSTACK_DB.query(sql, params, cb)
  local start = GetGameTimer()
  MySQL.query(sql, params, function(rows)
    local dur = GetGameTimer() - start
    if dur > RPSTACK_PERSISTENCE_CONFIG.slowQueryMs then
      print("[rpstack-persistence] slow query " .. dur .. "ms: " .. sql)
    end
    cb(rows or {})
  end)
end

function RPSTACK_DB.single(sql, params, cb)
  RPSTACK_DB.query(sql, params, function(rows)
    cb(rows[1])
  end)
end

function RPSTACK_DB.execute(sql, params, cb)
  local start = GetGameTimer()
  MySQL.update(sql, params, function(affected)
    local dur = GetGameTimer() - start
    if dur > RPSTACK_PERSISTENCE_CONFIG.slowQueryMs then
      print("[rpstack-persistence] slow execute " .. dur .. "ms: " .. sql)
    end
    cb(affected or 0)
  end)
end

function RPSTACK_DB.insert(sql, params, cb)
  local start = GetGameTimer()
  MySQL.insert(sql, params, function(insertId)
    local dur = GetGameTimer() - start
    if dur > RPSTACK_PERSISTENCE_CONFIG.slowQueryMs then
      print("[rpstack-persistence] slow insert " .. dur .. "ms: " .. sql)
    end
    cb(insertId)
  end)
end

function RPSTACK_DB.ping(cb)
  RPSTACK_DB.query("SELECT 1 AS ok", {}, function(rows)
    if rows and rows[1] then
      cb(true, nil)
    else
      cb(false, "no response from database")
    end
  end)
end