exports('rpstack:identity:getSession', function(src)
  local session = RPSTACK_IDENTITY_SESSION.getSession(src)
  if not session then
    return { ok = false, error = RPSTACK_ERRORS.NOT_FOUND }
  end
  return { ok = true, session = session }
end)

-- Async exports use a callback pattern.
-- Caller: exports['rpstack-identity']['rpstack:identity:getCharacters'](src, function(result) ... end)

exports('rpstack:identity:getCharacters', function(src, cb)
  RPSTACK_IDENTITY_CHARACTER.getCharacters(src, cb)
end)

exports('rpstack:identity:createCharacter', function(src, payload, cb)
  RPSTACK_IDENTITY_CHARACTER.createCharacter(src, payload, cb)
end)

exports('rpstack:identity:selectCharacter', function(src, char_id, cb)
  RPSTACK_IDENTITY_CHARACTER.selectCharacter(src, char_id, cb)
end)

exports('rpstack:identity:getActiveCharacter', function(src)
  local character = RPSTACK_IDENTITY_CHARACTER.getActiveCharacter(src)
  return { ok = true, character = character }
end)