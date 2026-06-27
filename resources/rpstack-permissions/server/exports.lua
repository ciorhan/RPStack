-- rpstack:permissions:hasPermission(source, permission) → boolean
-- Sync. Fast in-memory check. Use this in hot paths.
exports('rpstack:permissions:hasPermission', function(src, permission)
  return RPSTACK_PERMISSIONS.hasPermission(src, permission)
end)

-- rpstack:permissions:getRoles(source) → string[]
-- Sync. Returns list of role names for the player.
exports('rpstack:permissions:getRoles', function(src)
  return RPSTACK_PERMISSIONS.getRoles(src)
end)

-- rpstack:permissions:addRole(account_id, role_name, cb)
-- Async. Adds role and refreshes cache if player is online.
exports('rpstack:permissions:addRole', function(account_id, role_name, cb)
  RPSTACK_PERMISSIONS.addRole(account_id, role_name, cb)
end)

-- rpstack:permissions:removeRole(account_id, role_name, cb)
exports('rpstack:permissions:removeRole', function(account_id, role_name, cb)
  RPSTACK_PERMISSIONS.removeRole(account_id, role_name, cb)
end)