RPSTACK_PERMISSIONS = {}

-- Check if a source player's primary identifier is a superadmin.
local function isSuperadmin(src)
  local session = exports['rpstack-identity']['rpstack:identity:getSession'](src)
  if not session or not session.ok then return false end
  return RPSTACK_PERMISSIONS_CONFIG.superadmins[session.session.primaryIdentifier] == true
end

-- Load roles and permissions for an account into the cache.
-- Called on player connect. cb()
function RPSTACK_PERMISSIONS.loadForAccount(account_id, cb)
  RPSTACK_PERMISSIONS_REPO.getAccountPermissions(account_id, function(rows)
    local roles       = {}
    local permissions = {}
    local seen_roles  = {}

    for _, row in ipairs(rows) do
      if not seen_roles[row.role_name] then
        seen_roles[row.role_name] = true
        roles[#roles + 1] = row.role_name
      end
      if row.permission then
        permissions[row.permission] = true
      end
    end

    RPSTACK_PERMISSIONS_STATE.cache[account_id] = {
      roles       = roles,
      permissions = permissions,
    }

    cb()
  end)
end

-- Clear cache on disconnect.
function RPSTACK_PERMISSIONS.clearForAccount(account_id)
  RPSTACK_PERMISSIONS_STATE.cache[account_id] = nil
end

-- Check if a player has a permission. Sync — no DB hit.
-- Returns true for superadmins regardless of cache.
function RPSTACK_PERMISSIONS.hasPermission(src, permission)
  if isSuperadmin(src) then return true end

  local session = exports['rpstack-identity']['rpstack:identity:getSession'](src)
  if not session or not session.ok then return false end

  local cache = RPSTACK_PERMISSIONS_STATE.cache[session.session.account_id]
  if not cache then return false end

  return cache.permissions[permission] == true
end

-- Get roles for a player. Sync.
function RPSTACK_PERMISSIONS.getRoles(src)
  local session = exports['rpstack-identity']['rpstack:identity:getSession'](src)
  if not session or not session.ok then return {} end

  local cache = RPSTACK_PERMISSIONS_STATE.cache[session.session.account_id]
  if not cache then return {} end

  return cache.roles
end

-- Add a role to an account and refresh cache.
function RPSTACK_PERMISSIONS.addRole(account_id, role_name, cb)
  RPSTACK_PERMISSIONS_REPO.findRole(role_name, function(role)
    if not role then
      return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    end

    RPSTACK_PERMISSIONS_REPO.addAccountRole(account_id, role.id, function(affected)
      -- Refresh cache if player is online
      local cache = RPSTACK_PERMISSIONS_STATE.cache[account_id]
      if cache then
        RPSTACK_PERMISSIONS.loadForAccount(account_id, function() end)
      end

      RPSTACK_LOG.info("permissions", "role added", {
        account_id = account_id,
        role       = role_name,
      })

      cb({ ok = true })
    end)
  end)
end

-- Remove a role from an account and refresh cache.
function RPSTACK_PERMISSIONS.removeRole(account_id, role_name, cb)
  RPSTACK_PERMISSIONS_REPO.findRole(role_name, function(role)
    if not role then
      return cb({ ok = false, error = RPSTACK_ERRORS.NOT_FOUND })
    end

    RPSTACK_PERMISSIONS_REPO.removeAccountRole(account_id, role.id, function(affected)
      local cache = RPSTACK_PERMISSIONS_STATE.cache[account_id]
      if cache then
        RPSTACK_PERMISSIONS.loadForAccount(account_id, function() end)
      end

      RPSTACK_LOG.info("permissions", "role removed", {
        account_id = account_id,
        role       = role_name,
      })

      cb({ ok = true })
    end)
  end)
end