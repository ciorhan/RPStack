RPSTACK_PERSISTENCE_READY = false

CreateThread(function()
  RPSTACK_LOG.info("persistence", "rpstack-persistence starting")

  -- 1. Verify database connectivity
  RPSTACK_DB.ping(function(ok, err)
    if not ok then
      RPSTACK_LOG.error("persistence", "database connection failed", { err = err })
      -- Do not mark ready — dependent resources will fail their own startup checks
      return
    end

    RPSTACK_LOG.info("persistence", "database connected")

    -- 2. Run all registered migrations
    -- Note: other resources register migrations during their own startup.
    -- We wait one tick so all resources in the load order have had a chance to register.
    Wait(0)

    RPSTACK_MIGRATIONS.run(function(ok, err)
      if not ok then
        RPSTACK_LOG.error("persistence", "migration runner failed", { err = err })
        return
      end

      RPSTACK_PERSISTENCE_READY = true
      RPSTACK_LOG.info("persistence", "rpstack-persistence ready")

      -- Signal other resources that persistence is available
      TriggerEvent("rpstack:persistence:ready")
    end)
  end)
end)