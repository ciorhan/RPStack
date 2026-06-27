# Creating a Resource

Use the `create-resource` Claude Code skill for guided creation. This doc explains the reasoning.

## 1. Name and place it

```
resources/rpstack-<name>/
```

The `rpstack-` prefix is mandatory. It signals framework ownership and avoids collisions.

## 2. Write fxmanifest.lua first

```lua
fx_version 'cerulean'
game 'rdr3'
lua54 'yes'

name 'rpstack-<name>'
description '...'
version '0.0.1'

dependency 'rpstack-core'
-- add rpstack-persistence if you need DB

shared_scripts { 'shared/*.lua' }
server_scripts {
  'config/server.lua',
  'server/state.lua',
  'server/repositories/<name>_repo.lua',
  'server/exports.lua',
  'server/main.lua',   -- always last
}
client_scripts { 'client/main.lua' }
```

Load order within `server_scripts` matters — state before repositories, repositories before exports, main always last.

## 3. Config via convars

```lua
-- config/server.lua
RPSTACK_<NAME>_CONFIG = {}
RPSTACK_<NAME>_CONFIG.someSetting = GetConvar('rpstack:<name>:someSetting', 'default')
```

## 4. Exports

Match the owning resource's established export-name convention. Persistence and factions currently use simple names; identity and economy expose namespaced names. Do not rename an existing public contract merely to make its style uniform.

Colon syntax supplies the export proxy receiver for simple identifier-compatible names. Bracket syntax requires the proxy as its explicit first argument and is required for namespaced names:

```lua
exports['rpstack-persistence']:registerMigration(name, sql)

local economy = exports['rpstack-economy']
economy['rpstack:economy:getBalance'](economy, source, callback)
```

Cross-resource callbacks are Cfx function references and may have Lua type `table` at the export boundary. For asynchronous domain exports, use the canonical adapter in [Export invocation and callbacks](../architecture/overview.md#export-invocation-and-callbacks) before calling domain code. Domain functions should continue requiring a native Lua function. Persistence's low-level DB proxy is an existing pass-through exception.

## 5. Startup sequence in main.lua

```lua
-- Register migrations at file scope before persistence becomes ready.
exports['rpstack-persistence']:registerMigration(
  '<name>_001_create_table',
  "CREATE TABLE IF NOT EXISTS ..."
)

AddEventHandler('rpstack:persistence:ready', function()
  CreateThread(function()
    Wait(0)
    RPSTACK_LOG.info("<name>", "rpstack-<name> starting")
    -- hydrate caches and register event handlers
    RPSTACK_LOG.info("<name>", "rpstack-<name> ready")
  end)
end)
```

## 6. Migrations

```lua
exports['rpstack-persistence']:registerMigration(
  '<name>_001_create_table',
  "CREATE TABLE IF NOT EXISTS `your_table` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `account_id` INT UNSIGNED NOT NULL, `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), INDEX `idx_account_id` (`account_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
)
```

Migration registration is declarative; there is no module-facing `runMigrations()` export. Keep migration names stable and SQL strings single-line because multiline Lua strings do not cross the Cfx export boundary reliably.

## 7. Security checklist before first commit

- [ ] All net event handlers capture `local src = source` immediately
- [ ] All inputs validated before any logic
- [ ] No client payload used as DB key
- [ ] Rate limit applied if client-triggered
- [ ] Audit log for state-changing operations
