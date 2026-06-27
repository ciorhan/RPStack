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

```lua
-- server/exports.lua
exports('rpstack:<name>:<action>', function(...)
  -- validate inputs first
  -- call service/repo
  -- return { ok = true/false, data/error = ... }
end)
```

## 5. Startup sequence in main.lua

```lua
CreateThread(function()
  RPSTACK_LOG.info("<name>", "rpstack-<name> starting")
  -- run migrations
  -- register services
  -- register event handlers HERE (not before)
  RPSTACK_LOG.info("<name>", "rpstack-<name> ready")
end)
```

## 6. Migrations

```sql
-- migrations/001_init.sql
CREATE TABLE IF NOT EXISTS `your_table` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_id` INT UNSIGNED NOT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_account_id` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## 7. Security checklist before first commit

- [ ] All net event handlers capture `local src = source` immediately
- [ ] All inputs validated before any logic
- [ ] No client payload used as DB key
- [ ] Rate limit applied if client-triggered
- [ ] Audit log for state-changing operations
