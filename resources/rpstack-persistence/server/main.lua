RPSTACK_PERSISTENCE_READY = false

CreateThread(function()
  -- Wait two ticks to ensure rpstack-core globals are available
  Wait(0)
  Wait(0)

  print("[rpstack-persistence] starting")

  RPSTACK_DB.ping(function(ok, err)
    if not ok then
      print("[rpstack-persistence] ERROR: database connection failed: " .. tostring(err))
      return
    end

    print("[rpstack-persistence] database connected")

    Wait(0)

    RPSTACK_MIGRATIONS.run(function(success, runErr)
      if not success then
        print("[rpstack-persistence] ERROR: migration runner failed: " .. tostring(runErr))
        return
      end

      RPSTACK_PERSISTENCE_READY = true
      print("[rpstack-persistence] ready")
      TriggerEvent("rpstack:persistence:ready")
    end)
  end)
end)