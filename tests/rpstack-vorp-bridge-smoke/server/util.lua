RPSTACK_VSMOKE_ENABLED = GetConvarInt('rpstack:smoke:enabled', 0) == 1
if not RPSTACK_VSMOKE_ENABLED then
  print('[rpstack-vorp-bridge-smoke] disabled')
  return
end

VSMOKE = {}

-- Smoke-owned names. Never VORP events or VORP state keys.
VSMOKE.STATE_PROBE_KEY      = 'rpstackSmokeProbe'
VSMOKE.NET_STATE_PROBE      = 'rpstack:vorpsmoke:net:stateProbe'
VSMOKE.PEER_RESOURCE        = 'rpstack-vorp-bridge-smoke-peer'

function VSMOKE.report(check, passed, evidence)
  print(('[SMOKE] %s %s %s'):format(passed and 'PASS' or 'FAIL', check, json.encode(evidence or {})))
end

function VSMOKE.info(check, message, evidence)
  print(('[SMOKE] INFO %s %s %s'):format(check, message, json.encode(evidence or {})))
end

function VSMOKE.isPositiveInteger(value)
  return type(value) == 'number' and value > 0 and value == math.floor(value)
end

function VSMOKE.consoleOnly(source, usage)
  if source ~= 0 then
    print('[SMOKE] Run this command from the FXServer console.')
    return false
  end
  return true
end

-- Parses and validates a connected player source argument.
function VSMOKE.playerArg(args, usage)
  local src = tonumber(args[1])
  if not VSMOKE.isPositiveInteger(src) or GetPlayerName(src) == nil then
    print('[SMOKE] Usage: ' .. usage)
    return nil
  end
  return src
end

function VSMOKE.core()
  return exports.vorp_core:GetCore()
end

-- Fresh VORP character for a source, or nil.
function VSMOKE.vorpCharacter(src)
  local user = VSMOKE.core().getUser(src)
  if not user then return nil end
  local character = user.getUsedCharacter
  if type(character) ~= 'table' or not character.charIdentifier then return nil end
  return character
end

function VSMOKE.moneyEquals(a, b)
  return type(a) == 'number' and type(b) == 'number' and math.abs(a - b) < 0.001
end

function VSMOKE.bridge()
  return exports['rpstack-vorp-bridge']
end

-- Test-only DB read through rpstack-persistence (never used by production code).
function VSMOKE.readCharacterMoney(characterId, cb)
  exports['rpstack-persistence']:dbSingle(
    'SELECT money FROM characters WHERE charidentifier = ? LIMIT 1',
    { characterId },
    function(row) cb(row and tonumber(row.money) or nil) end
  )
end
