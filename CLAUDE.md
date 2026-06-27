# RPStack — Claude Code Context

## What this is

A modular, server-authoritative RedM roleplay framework. Core + modules model. Greenfield — no FiveM carryover. Loose VORP/RSG export compatibility is a goal. 1890s frontier setting, player-driven economy, faction-based power.

## Stack

- Runtime: RedM / Cfx.re (CfxLua, Lua 5.4)
- DB: oxmysql + MySQL/MariaDB
- NUI: plain HTML/CSS/JS (no build step)
- No ox_lib dependency in v0

## Resource layout

```
resources/
  rpstack-core/         config, logger, service registry, errors
  rpstack-persistence/  oxmysql wrapper, migration runner, DB proxy exports
  rpstack-identity/     accounts, sessions, multi-character
  rpstack-economy/      cash + bank balances, transaction log
  rpstack-permissions/  roles, policy checks, superadmin bypass
  rpstack-factions/     multi-faction membership, ranks, relationships, treasury
```

Load order must follow this sequence. Each resource declares `dependency` in its fxmanifest.

## CfxLua runtime realities (learned in production)

These are verified facts — not assumptions:

1. **Globals do NOT cross resource boundaries.** Each resource has an isolated Lua environment. `RPSTACK_LOG`, `RPSTACK_DB`, etc. defined in one resource are invisible in another. Every resource that needs logging or DB access must load its own `shared/logger.lua` and `shared/db.lua`.

2. **Export call syntax matters.** Use colon syntax only:

   ```lua
   -- CORRECT
   exports['rpstack-persistence']:registerMigration(name, sql)
   -- WRONG — drops first argument silently
   exports['rpstack-persistence']['registerMigration'](name, sql)
   ```

3. **Export names must be simple strings** — no colons or namespacing in the export name itself. `exports('registerMigration', fn)` not `exports('rpstack:persistence:registerMigration', fn)`.

   **Exception:** rpstack-economy uses namespaced export names as a convention:
   `exports('rpstack:economy:getBalance', fn)` — called as
   `exports['rpstack-economy']['rpstack:economy:getBalance'](exports['rpstack-economy'], src, cb)`

4. **Multiline strings `[[...]]` fail across export boundaries** — pass SQL and other long strings as single-line quoted strings.

5. **`rpstack:persistence:ready` event** is the startup gate. All resources wait for this before registering event handlers. Wrap the handler body in `CreateThread(function() Wait(0) ... end)` to ensure globals are ready.

6. **`rdr3_warning` required** in every fxmanifest or resource won't start on RedM.

7. **System resources** (`sessionmanager-rdr3`, `mapmanager`, `spawnmanager`, `hardcap`) must be copied from `cfx-server-data` into your resources folder and ensured before framework resources.

---

## Verified patterns (extracted from production code — match these exactly)

> These patterns are ground truth. Every new module must follow them without deviation.
> Before writing any new module, read the most recently built resource as reference.

### Table naming

All DB tables use the `rpstack_` prefix:

```
rpstack_accounts
rpstack_characters
rpstack_economy_accounts
rpstack_economy_transactions
rpstack_faction_ranks
rpstack_faction_members
_rpstack_migrations        (internal, managed by persistence)
```

Never create a table without the `rpstack_` prefix.

---

### Migration registration pattern

Migrations are registered **before** the `rpstack:persistence:ready` event, at the top level of `server/main.lua`. They run automatically — there is no `runMigrations()` export.

```lua
-- TOP LEVEL of server/main.lua — outside any event handler
exports['rpstack-persistence']:registerMigration(
  'module_001_create_table',
  "CREATE TABLE IF NOT EXISTS `rpstack_module_table` (...) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
)

exports['rpstack-persistence']:registerMigration(
  'module_002_add_column',
  "ALTER TABLE `rpstack_module_table` ADD COLUMN IF NOT EXISTS `new_col` VARCHAR(16) NOT NULL DEFAULT 'value'"
)

-- THEN the startup gate
AddEventHandler('rpstack:persistence:ready', function()
  CreateThread(function()
    Wait(0)
    -- module logic here
  end)
end)
```

**Rules:**

- Migration names are unique strings: `modulename_NNN_description`
- SQL is a single-line string — no multiline `[[...]]`
- Migrations are idempotent: always use `CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`
- Never call a `runMigrations()` export — it does not exist

---

### DB call pattern (RPSTACK_DB)

All DB operations are **async with callbacks**. There is no sync variant.

```lua
-- shared/db.lua is loaded via shared_scripts in fxmanifest
-- It exposes RPSTACK_DB which delegates to rpstack-persistence exports

-- Query (returns array of rows, never nil — empty array if no results)
RPSTACK_DB.query(sql, params, function(rows)
  -- rows is always a table, may be empty
end)

-- Single row
RPSTACK_DB.single(sql, params, function(row)
  -- row is nil if not found
end)

-- Execute (UPDATE/DELETE — returns affected row count)
RPSTACK_DB.execute(sql, params, function(affected)
  -- affected is 0 if nothing changed
end)

-- Insert (returns insertId)
RPSTACK_DB.insert(sql, params, function(insertId)
  -- insertId is nil if insert failed
end)
```

**Rules:**

- Always use `{}` not `nil` for empty params
- Never nest more than 3 callbacks — extract named functions if deeper
- Fire-and-forget inserts (audit logs) still need a callback: `function() end`

---

### Shared files (required in every resource that uses logging or DB)

Every non-core resource must declare these in `fxmanifest.lua` **before all other scripts**:

```lua
shared_scripts {
  'shared/logger.lua',   -- provides RPSTACK_LOG
  'shared/db.lua',       -- provides RPSTACK_DB
  'shared/constants.lua',
  'shared/contracts.lua',
}
```

Copy `shared/logger.lua` and `shared/db.lua` from `rpstack-economy/shared/` — they are identical across all resources.

---

### Export patterns

**Persistence exports** — simple names, no namespace:

```lua
exports('registerMigration', fn)   -- called as exports['rpstack-persistence']:registerMigration(...)
exports('dbQuery', fn)
exports('dbInsert', fn)
exports('dbExecute', fn)
exports('dbSingle', fn)
```

**Economy exports** — namespaced names (exception to the simple name rule):

```lua
exports('rpstack:economy:getBalance', fn)
exports('rpstack:economy:addMoney', fn)
exports('rpstack:economy:removeMoney', fn)
exports('rpstack:economy:createAccountForOwner', fn)
exports('rpstack:economy:adjustOwnerCash', fn)
exports('rpstack:economy:adjustCashByCharId', fn)
```

Called from other resources as:

```lua
local econ = exports['rpstack-economy']
econ['rpstack:economy:addMoney'](econ, src, 'cash', amount, reason, function(result)
  -- result: { ok, cash, bank, error }
end)
```

**Factions exports** — simple names, no namespace:

```lua
exports('createFaction', fn)    -- called as exports['rpstack-factions']:createFaction(...)
exports('getFaction', fn)
exports('isMember', fn)
exports('characterHasFactionPerm', fn)
```

**Sync vs async:**

- Exports that read from in-memory cache only → **sync**, return value directly
- Exports that touch DB or call economy → **async**, require callback as last argument
- Always document which is which in `shared/contracts.lua`

---

### Economy account model

```
rpstack_economy_accounts
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY
  char_id     INT UNSIGNED NULL          -- NULL for non-character owners
  owner_type  VARCHAR(16) DEFAULT 'character'   -- 'character' | 'faction' | ...
  owner_id    INT UNSIGNED NULL          -- faction id, town id, etc.
  account_type VARCHAR(16) DEFAULT 'default'    -- 'default' | 'treasury' | ...
  cash        INT UNSIGNED DEFAULT 0
  bank        INT UNSIGNED DEFAULT 0
```

- Character accounts: `owner_type='character'`, `owner_id=char_id`
- Faction treasury: `owner_type='faction'`, `owner_id=faction_id`, `account_type='treasury'`
- All money mutations go through `RPSTACK_LEDGER.apply()` for character accounts
- Single-account non-character changes use `RPSTACK_ECONOMY_ACCOUNTS.adjustOwnerCash()`
- Cross-owner movements use `RPSTACK_ECONOMY_ACCOUNTS.transferCash()` so debit and credit happen atomically
- Never mutate balances with a raw UPDATE outside the economy repository

---

### Economy exports — exact signatures

```lua
-- All take src (server source id), not character id
exports['rpstack-economy']['rpstack:economy:addMoney'](econ, src, account, amount, reason, cb)
exports['rpstack-economy']['rpstack:economy:removeMoney'](econ, src, account, amount, reason, cb)
exports['rpstack-economy']['rpstack:economy:getBalance'](econ, src, cb)
exports['rpstack-economy']['rpstack:economy:deposit'](econ, src, amount, reason, cb)
exports['rpstack-economy']['rpstack:economy:withdraw'](econ, src, amount, reason, cb)

-- These take characterId (not src) — for offline character operations
exports['rpstack-economy']['rpstack:economy:adjustCashByCharId'](econ, characterId, delta, reason, cb)

-- These take ownerType + ownerId — for non-character entities
exports['rpstack-economy']['rpstack:economy:createAccountForOwner'](econ, ownerType, ownerId, accountType, cb)
exports['rpstack-economy']['rpstack:economy:getAccountByOwner'](econ, ownerType, ownerId, accountType, cb)
exports['rpstack-economy']['rpstack:economy:adjustOwnerCash'](econ, ownerType, ownerId, accountType, delta, reason, cb)
exports['rpstack-economy']['rpstack:economy:transferCash'](econ, fromType, fromId, fromAccountType, toType, toId, toAccountType, amount, reason, cb)

-- Callback shape for all money operations:
-- cb({ ok=bool, cash=number|nil, bank=number|nil, error=string|nil })
-- cb({ ok=bool, newCash=number|nil, error=string|nil })  -- for adjustOwnerCash
```

---

### fxmanifest.lua template

```lua
fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name        'rpstack-modulename'
author      'RPStack'
description 'RPStack modulename: short description'
version     '0.0.1'

dependencies {
  'rpstack-core',
  'rpstack-persistence',
  -- add others as needed
}

shared_scripts {
  'shared/logger.lua',
  'shared/db.lua',
  'shared/constants.lua',
  'shared/contracts.lua',
}

server_scripts {
  'config/server.lua',
  'server/state.lua',
  'server/repository.lua',
  'server/cache.lua',     -- if module has in-memory cache
  'server/audit.lua',     -- if module has audit log
  -- domain files
  'server/exports.lua',
  'server/main.lua',      -- always last
}

client_scripts {
  'client/main.lua',
}
```

---

### server/main.lua template

```lua
-- Migrations at top level (before event handler)
exports['rpstack-persistence']:registerMigration('module_001_...', "CREATE TABLE IF NOT EXISTS ...")

-- Startup gate
AddEventHandler('rpstack:persistence:ready', function()
  CreateThread(function()
    Wait(0)

    RPSTACK_LOG.info("module", "starting")

    -- hydrate cache, register listeners, etc.

    RPSTACK_LOG.info("module", "ready")
    TriggerEvent('rpstack:module:ready')
  end)
end)
```

---

### Shared files pattern

```lua
-- shared/db.lua (identical in every resource)
RPSTACK_DB = RPSTACK_DB or {}
function RPSTACK_DB.query(sql, params, cb)   exports['rpstack-persistence']:dbQuery(sql, params, cb)   end
function RPSTACK_DB.single(sql, params, cb)  exports['rpstack-persistence']:dbSingle(sql, params, cb)  end
function RPSTACK_DB.execute(sql, params, cb) exports['rpstack-persistence']:dbExecute(sql, params, cb) end
function RPSTACK_DB.insert(sql, params, cb)  exports['rpstack-persistence']:dbInsert(sql, params, cb)  end
```

---

## Shared files pattern (required in every resource)

Each non-core resource must have:

- `shared/logger.lua` — local copy of RPSTACK_LOG (identical across resources)
- `shared/db.lua` — local RPSTACK_DB wrapper that delegates to persistence exports

---

## Architecture rules (non-negotiable)

1. Client requests. Server decides. No exceptions.
2. Every state-changing server function validates: type, range, ownership, permissions.
3. Modules own their DB tables. No cross-module table access. Use exports.
4. Export names are simple strings (exception: economy uses namespaced names — match existing convention per module).
5. Network events follow `rpstack:<module>:<event>` naming.
6. Never trust: source, payload values, entity ownership, positions from client.
7. Always capture `local src = source` immediately in event handlers — never defer it.
8. No global mutable state without explicit ownership and lifecycle documentation.

---

## Identity model

- Primary identifier: `license2 → license → fivem` fallback chain
- Internal key: `account_id` (DB auto-increment) — all cross-module references use this
- Sessions are in-memory. Accounts and characters are persisted.

---

## Security invariants

- Deferrals used for connection screening before player enters session
- Economy operations go through the ledger — never direct balance mutation
- Audit log entries for: money changes, character create/delete, role changes

---

## server.cfg load order

```
stop sessionmanager
ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager-rdr3
ensure hardcap
ensure rconlog
ensure oxmysql
ensure rpstack-core
ensure rpstack-persistence
ensure rpstack-identity
ensure rpstack-permissions
ensure rpstack-economy
ensure rpstack-factions
```

---

## Testing from FXServer console

Use the `execute` command to run Lua in a specific resource context:
execute rpstack-factions print(json.encode(exports['rpstack-factions']:listFactions()))

Rules:

- Always specify the resource name after `execute`
- Async exports cannot be tested this way — they require a callback. Use a temporary test file in server_scripts instead.
- Sync cache-read exports can be tested directly from console.
- `json.encode` is available globally in CfxLua — use it to print table results.

## getActiveCharacter export syntax

Economy uses bracket syntax to call identity exports (verified in production):

```lua
local identity = exports['rpstack-identity']
identity['rpstack:identity:getActiveCharacter'](identity, src).character
```

Note: namespaced exports require bracket syntax and the export proxy as the first argument. The proxy consumes that receiver before forwarding the documented arguments.

---

## Definition of done (per task)

- [ ] Server-authoritative (no client trust)
- [ ] Input validated (type, range, ownership)
- [ ] Structured log entry for state changes
- [ ] Export uses correct naming convention for this module
- [ ] `shared/logger.lua` and `shared/db.lua` present and in fxmanifest shared_scripts first
- [ ] `rdr3_warning` in fxmanifest
- [ ] fxmanifest load order correct (logger + db before everything)
- [ ] No cross-module DB access
- [ ] All DB calls async with callbacks — no sync variants
- [ ] Table names use `rpstack_` prefix
- [ ] Migrations registered at top level of main.lua, before event handler
- [ ] No `runMigrations()` call — persistence runs them automatically
- [ ] SQL strings are single-line — no `[[...]]`

---

## Key docs

- Architecture: `docs/architecture/overview.md`
- Security: `docs/security/threat-model.md`
- Creating a resource: `docs/development/creating-a-resource.md`
- ADR log: `docs/architecture/adr/README.md`
- References: `docs/references/README.md`
