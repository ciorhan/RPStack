-- Local DB wrapper for resources outside rpstack-persistence.
-- Delegates all queries to rpstack-persistence exports.
-- This file is loaded via shared_scripts in each resource that needs DB access.

RPSTACK_DB = RPSTACK_DB or {}

function RPSTACK_DB.query(sql, params, cb)
  exports['rpstack-persistence']:dbQuery(sql, params, cb)
end

function RPSTACK_DB.single(sql, params, cb)
  exports['rpstack-persistence']:dbSingle(sql, params, cb)
end

function RPSTACK_DB.execute(sql, params, cb)
  exports['rpstack-persistence']:dbExecute(sql, params, cb)
end

function RPSTACK_DB.insert(sql, params, cb)
  exports['rpstack-persistence']:dbInsert(sql, params, cb)
end