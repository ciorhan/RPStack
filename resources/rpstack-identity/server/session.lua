-- Resolves player identifiers and establishes an account-backed session.

local function pickPrimaryIdentifier(src)
  -- Priority: license2 → license → fivem
  -- Never trust identifiers from the client — always read from server native.
  local license2, license, fivem

  for i = 0, GetNumPlayerIdentifiers(src) - 1 do
    local id = GetPlayerIdentifier(src, i)
    if id then
      if id:sub(1, 9)  == "license2:" then license2 = id
      elseif id:sub(1, 8) == "license:"  then license  = id
      elseif id:sub(1, 6) == "fivem:"    then fivem    = id
      end
    end
  end

  return license2 or license or fivem
end

RPSTACK_IDENTITY_SESSION = {}

-- Called on playerConnecting (with deferrals) to establish a session.
-- cb(session | nil, err)
function RPSTACK_IDENTITY_SESSION.onPlayerJoining(src, cb)
  local primary = pickPrimaryIdentifier(src)
  local name    = GetPlayerName(src) or ("player_" .. tostring(src))

  if not primary then
    RPSTACK_LOG.warn("identity", "player has no valid identifier", { source = src })
    cb(nil, RPSTACK_ERRORS.VALIDATION_FAILED)
    return
  end

  -- Find or create account
  RPSTACK_ACCOUNT_REPO.findByIdentifier(primary, function(account)
    if account then
      -- Existing account
      local session = {
        source            = src,
        account_id        = account.id,
        primaryIdentifier = primary,
        name              = name,
        joinedAt          = os.time(),
      }
      RPSTACK_IDENTITY_STATE.sessions[src] = session
      RPSTACK_LOG.info("identity", "session created", { source = src, account_id = account.id })
      cb(session, nil)
    else
      -- New account
      RPSTACK_ACCOUNT_REPO.create(primary, name, function(account_id)
        if not account_id then
          RPSTACK_LOG.error("identity", "failed to create account", { source = src, primary = primary })
          cb(nil, RPSTACK_ERRORS.INTERNAL)
          return
        end

        local session = {
          source            = src,
          account_id        = account_id,
          primaryIdentifier = primary,
          name              = name,
          joinedAt          = os.time(),
        }
        RPSTACK_IDENTITY_STATE.sessions[src] = session
        RPSTACK_LOG.info("identity", "account created", { source = src, account_id = account_id })
        cb(session, nil)
      end)
    end
  end)
end

function RPSTACK_IDENTITY_SESSION.onPlayerDropped(src, reason)
  local session = RPSTACK_IDENTITY_STATE.sessions[src]
  RPSTACK_IDENTITY_STATE.sessions[src] = nil
  RPSTACK_IDENTITY_STATE.activeCharacterBySource[src] = nil

  RPSTACK_LOG.info("identity", "session dropped", {
    source     = src,
    reason     = reason or "unknown",
    account_id = session and session.account_id or "none",
  })
end

function RPSTACK_IDENTITY_SESSION.getSession(src)
  return RPSTACK_IDENTITY_STATE.sessions[src]
end