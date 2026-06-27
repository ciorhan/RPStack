# Architecture Overview

## Model

RPStack is built as **core + modules**. Core provides the runtime foundation. Modules provide gameplay systems behind stable, versioned exports. Modules never reach into each other's internals.

## Resources and responsibilities

```
rpstack-core
  Config (convars), structured logger, service registry, shared error codes.
  No gameplay logic. No DB access.
  NOTE: RPSTACK_LOG defined here is NOT accessible in other resources.
  Each resource loads its own shared/logger.lua.

rpstack-persistence
  oxmysql wrapper (RPSTACK_DB), migration runner, DB connectivity check.
  Exposes DB proxy exports: dbQuery, dbSingle, dbExecute, dbInsert.
  Fires rpstack:persistence:ready when migrations complete.
  All other resources wait for this event before registering handlers.

rpstack-identity
  Accounts (license identifier → internal account_id mapping).
  Sessions (in-memory, per connection).
  Characters (DB-backed, multi-character per account).
  Owns: rpstack_accounts, rpstack_characters.

rpstack-economy
  Cash and bank balances per character.
  All mutations go through the ledger — no direct balance updates.
  Immutable transaction log for every money movement.
  Owns: rpstack_economy_accounts, rpstack_economy_transactions.

rpstack-permissions
  Roles assigned to accounts (not characters).
  Permission cache loaded into memory on session creation.
  Superadmin bypass via convar.
  Owns: rpstack_roles, rpstack_role_permissions, rpstack_account_roles.
```

## Load order

```
rpstack-core
  └── rpstack-persistence
        └── rpstack-identity
              └── rpstack-permissions
                    └── rpstack-economy
```

## Startup sequence

```
1. System resources start (sessionmanager-rdr3, mapmanager, etc.)
2. oxmysql starts — DB connection established
3. rpstack-core loads — logger and config available (isolated to core)
4. rpstack-persistence loads — registers DB wrapper
5. rpstack-identity loads — registers 2 migrations, loads shared/logger.lua + shared/db.lua
6. rpstack-permissions loads — registers 3 migrations
7. rpstack-economy loads — registers 2 migrations
8. rpstack-persistence CreateThread fires (after Wait(0)x2):
   → pings DB
   → runs all 7 migrations
   → fires rpstack:persistence:ready
9. Each module's ready handler fires (wrapped in CreateThread + Wait(0)):
   → identity: registers playerConnecting + playerDropped
   → permissions: seeds default roles, registers session listeners
   → economy: registers characterCreated listener
```

## Shared files pattern

CfxLua isolates each resource's Lua environment. Globals don't cross boundaries. Every resource that needs logging or DB access loads local copies:

```
shared/logger.lua   — defines local RPSTACK_LOG (print-based, same format as core)
shared/db.lua       — defines local RPSTACK_DB (delegates to persistence exports)
```

These are identical across resources and loaded automatically via `shared_scripts { 'shared/*.lua' }`.

## Export naming and call syntax

Export names are simple strings (no colons):

```lua
-- Define
exports('getSession', function(src) ... end)
exports('registerMigration', function(name, sql) ... end)

-- Call (colon syntax required — bracket syntax drops first argument)
exports['rpstack-identity']:getSession(src)
exports['rpstack-persistence']:registerMigration(name, sql)
```

## Player lifecycle

```
playerConnecting (with deferrals)
  → identity resolves identifier (license2 → license → fivem)
  → DB lookup: find or create account
  → session created in memory
  → TriggerEvent('rpstack:identity:sessionCreated', src, account_id)
  → permissions loads cache for account_id
  → deferrals.done() — player enters server

character selection
  → getCharacters → player sees their characters
  → selectCharacter(char_id) → server verifies ownership
  → activeCharacterBySource[src] = character
  → TriggerEvent('rpstack:identity:characterCreated', char_id) (on new char)
  → economy auto-creates balance row

playerDropped
  → TriggerEvent('rpstack:identity:sessionDropped', src, account_id)
  → permissions clears cache
  → session and activeCharacter cleared
```

## Data ownership

| Table                          | Owner               |
| ------------------------------ | ------------------- |
| `rpstack_accounts`             | rpstack-identity    |
| `rpstack_characters`           | rpstack-identity    |
| `rpstack_economy_accounts`     | rpstack-economy     |
| `rpstack_economy_transactions` | rpstack-economy     |
| `rpstack_roles`                | rpstack-permissions |
| `rpstack_role_permissions`     | rpstack-permissions |
| `rpstack_account_roles`        | rpstack-permissions |
| `_rpstack_migrations`          | rpstack-persistence |

## Error codes (shared via rpstack-core/shared/errors.lua)

| Code                | Meaning                                 |
| ------------------- | --------------------------------------- |
| `VALIDATION_FAILED` | Bad input                               |
| `NOT_AUTHORIZED`    | Permission denied or ownership mismatch |
| `NOT_FOUND`         | Entity does not exist                   |
| `CONFLICT`          | Duplicate or state conflict             |
| `INTERNAL`          | Unexpected server error                 |

## Key ADRs

- [ADR-001](adr/README.md) — Internal account_id decoupled from Cfx identifiers
- [ADR-002](adr/README.md) — No ox_lib in v0
- [ADR-003](adr/README.md) — oxmysql + MySQL/MariaDB only
- [ADR-004](adr/README.md) — Multi-character from v0
