AddEventHandler('playerJoining', function()
  local src = source
  RPSTACK_IDENTITY_SESSION.onPlayerJoining(src)

  if RPSTACK_IDENTITY_CONFIG.autoCreateCharacter then
    -- Dev convenience only; keep off in prod.
    RPSTACK_IDENTITY_CHARACTER.createCharacter(src, { firstName = "John", lastName = "Doe" })
  end
end)

AddEventHandler('playerDropped', function(reason)
  local src = source
  RPSTACK_IDENTITY_SESSION.onPlayerDropped(src, reason)
end)

CreateThread(function()
  RPSTACK_LOG.info("identity", "rpstack-identity starting")
  RPSTACK_LOG.info("identity", "rpstack-identity ready")
end)