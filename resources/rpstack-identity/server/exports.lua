local function localCallback(callback)
  if callback == nil then return nil end
  return function(result)
    callback(result)
  end
end

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
  RPSTACK_IDENTITY_CHARACTER.getCharacters(src, localCallback(cb))
end)

exports('rpstack:identity:createCharacter', function(src, payload, cb)
  RPSTACK_IDENTITY_CHARACTER.createCharacter(src, payload, localCallback(cb))
end)

exports('rpstack:identity:selectCharacter', function(src, char_id, cb)
  RPSTACK_IDENTITY_CHARACTER.selectCharacter(src, char_id, localCallback(cb))
end)

exports('rpstack:identity:getActiveCharacter', function(src)
  local character = RPSTACK_IDENTITY_CHARACTER.getActiveCharacter(src)
  return { ok = true, character = character }
end)

exports('rpstack:identity:getCharacterById', function(charId, cb)
  cb = localCallback(cb)
  if type(cb) ~= "function" then return end
  if type(charId) ~= "number"
    or charId <= 0
    or charId ~= math.floor(charId)
  then
    cb({ ok = false, error = RPSTACK_ERRORS.VALIDATION_FAILED })
    return
  end

  RPSTACK_CHARACTER_REPO.findById(charId, function(character)
    if not character then
      cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
      return
    end
    cb({ ok = true, character = character })
  end)
end)
