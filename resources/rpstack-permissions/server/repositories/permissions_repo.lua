-- Owns all queries for rpstack_roles, rpstack_role_permissions, rpstack_account_roles.

RPSTACK_PERMISSIONS_REPO = {}

-- Get all roles assigned to an account with their permissions.
-- cb(rows) where each row = { role_name, permission }
function RPSTACK_PERMISSIONS_REPO.getAccountPermissions(account_id, cb)
  RPSTACK_DB.query([[
    SELECT r.name AS role_name, rp.permission
    FROM rpstack_account_roles ar
    JOIN rpstack_roles r ON r.id = ar.role_id
    LEFT JOIN rpstack_role_permissions rp ON rp.role_id = r.id
    WHERE ar.account_id = ?
  ]], { account_id }, cb)
end

-- Get role id by name. cb(row | nil)
function RPSTACK_PERMISSIONS_REPO.findRole(name, cb)
  RPSTACK_DB.single(
    "SELECT id, name, label FROM rpstack_roles WHERE name = ? LIMIT 1",
    { name },
    cb
  )
end

-- Assign a role to an account. cb(affected)
function RPSTACK_PERMISSIONS_REPO.addAccountRole(account_id, role_id, cb)
  RPSTACK_DB.execute(
    "INSERT IGNORE INTO rpstack_account_roles (account_id, role_id) VALUES (?, ?)",
    { account_id, role_id },
    cb
  )
end

-- Remove a role from an account. cb(affected)
function RPSTACK_PERMISSIONS_REPO.removeAccountRole(account_id, role_id, cb)
  RPSTACK_DB.execute(
    "DELETE FROM rpstack_account_roles WHERE account_id = ? AND role_id = ?",
    { account_id, role_id },
    cb
  )
end

-- Seed default roles if they don't exist. cb()
function RPSTACK_PERMISSIONS_REPO.seedRoles(roles, cb)
  local function next(i)
    if i > #roles then return cb() end
    local r = roles[i]
    RPSTACK_DB.execute(
      "INSERT IGNORE INTO rpstack_roles (name, label) VALUES (?, ?)",
      { r.name, r.label },
      function() next(i + 1) end
    )
  end
  next(1)
end