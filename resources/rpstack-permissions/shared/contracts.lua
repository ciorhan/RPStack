RPSTACK_PERMISSIONS_CONTRACTS = {

  -- rpstack:permissions:hasPermission(source, permission) → boolean
  -- Sync. Superadmins always return true.
  hasPermission = {
    input  = { "source:number", "permission:string" },
    output = { "result:boolean" },
    async  = false,
    notes  = "permission format: 'module.action' e.g. 'economy.give', 'admin.kick'",
  },

  -- rpstack:permissions:getRoles(source) → string[]
  getRoles = {
    input  = { "source:number" },
    output = { "roles:string[]" },
    async  = false,
  },

  -- rpstack:permissions:addRole(account_id, role_name, cb)
  addRole = {
    input  = { "account_id:number", "role_name:string", "cb:function" },
    output = { "ok:boolean", "error:string|nil" },
    async  = true,
  },

  -- rpstack:permissions:removeRole(account_id, role_name, cb)
  removeRole = {
    input  = { "account_id:number", "role_name:string", "cb:function" },
    output = { "ok:boolean", "error:string|nil" },
    async  = true,
  },
}

-- Permission strings used by RPStack core modules:
-- "economy.give"       — give money to a player
-- "economy.take"       — take money from a player
-- "permissions.manage" — add/remove roles
-- "admin.kick"         — kick a player
-- "admin.ban"          — ban a player