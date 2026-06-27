-- Migration registration
exports('registerMigration', function(name, sql)
  RPSTACK_MIGRATIONS.register(name, sql)
end)

exports('isPersistenceReady', function()
  return RPSTACK_PERSISTENCE_READY == true
end)

-- DB proxy exports — allows other resources to use RPSTACK_DB via exports
exports('dbQuery', function(sql, params, cb)
  RPSTACK_DB.query(sql, params, cb)
end)

exports('dbSingle', function(sql, params, cb)
  RPSTACK_DB.single(sql, params, cb)
end)

exports('dbExecute', function(sql, params, cb)
  RPSTACK_DB.execute(sql, params, cb)
end)

exports('dbInsert', function(sql, params, cb)
  RPSTACK_DB.insert(sql, params, cb)
end)