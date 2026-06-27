-- Expose migration registration to other resources.
exports('rpstack:persistence:registerMigration', function(resource, name, sql)
  RPSTACK_MIGRATIONS.register(resource, name, sql)
end)

-- Expose a ready-check so dependent resources can confirm persistence is up.
exports('rpstack:persistence:isReady', function()
  return RPSTACK_PERSISTENCE_READY == true
end)