exports('rpstack:identity:getSession', function(src)
  local session = RPSTACK_IDENTITY_SESSION.getSession(src)
  if not session then
    return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND }
  end
  return { ok = true, session = session }
end)

exports('rpstack:identity:createCharacter', function(src, payload)
  return RPSTACK_IDENTITY_CHARACTER.createCharacter(src, payload)
end)

exports('rpstack:identity:getActiveCharacter', function(src)
  return RPSTACK_IDENTITY_CHARACTER.getActiveCharacter(src)
end)