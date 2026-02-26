CreateThread(function()
  RPSTACK_LOG.info("core", "rpstack-core starting", { env = RPSTACK_CONFIG.env })

  -- Example: register core utilities/services here later
  -- RPSTACK_SERVICES.register("logger", RPSTACK_LOG)

  RPSTACK_LOG.info("core", "rpstack-core ready")
end)