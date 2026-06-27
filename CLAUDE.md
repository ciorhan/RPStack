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

4. **Multiline strings `[[...]]` fail across export boundaries** — pass SQL and other long strings as single-line quoted strings.

5. **`rpstack:persistence:ready` event** is the startup gate. All resources wait for this before registering event handlers. Wrap the handler body in `CreateThread(function() Wait(0) ... end)` to ensure globals are ready.

6. **`rdr3_warning` required** in every fxmanifest or resource won't start on RedM.

7. **System resources** (`sessionmanager-rdr3`, `mapmanager`, `spawnmanager`, `hardcap`) must be copied from `cfx-server-data` into your resources folder and ensured before framework resources.

## Shared files pattern (required in every resource)

Each non-core resource must have:

- `shared/logger.lua` — local copy of RPSTACK_LOG (identical across resources)
- `shared/db.lua` — local RPSTACK_DB wrapper that delegates to persistence exports

## Architecture rules (non-negotiable)

1. Client requests. Server decides. No exceptions.
2. Every state-changing server function validates: type, range, ownership, permissions.
3. Modules own their DB tables. No cross-module table access. Use exports.
4. Export names are simple strings: `registerMigration`, `getSession`, `addMoney`, etc.
5. Network events follow `rpstack:<module>:<event>` naming.
6. Never trust: source, payload values, entity ownership, positions from client.
7. Always capture `local src = source` immediately in event handlers — never defer it.
8. No global mutable state without explicit ownership and lifecycle documentation.

## Identity model

- Primary identifier: `license2 → license → fivem` fallback chain
- Internal key: `account_id` (DB auto-increment) — all cross-module references use this
- Sessions are in-memory. Accounts and characters are persisted.

## Security invariants

- Deferrals used for connection screening before player enters session
- Economy operations go through the ledger — never direct balance mutation
- Audit log entries for: money changes, character create/delete, role changes

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
```

## Definition of done (per task)

- [ ] Server-authoritative (no client trust)
- [ ] Input validated (type, range, ownership)
- [ ] Structured log entry for state changes
- [ ] Export uses simple name, colon call syntax
- [ ] `shared/logger.lua` and `shared/db.lua` present if resource uses them
- [ ] `rdr3_warning` in fxmanifest
- [ ] fxmanifest load order correct
- [ ] No cross-module DB access

## Key docs

- Architecture: `docs/architecture/overview.md`
- Security: `docs/security/threat-model.md`
- Creating a resource: `docs/development/creating-a-resource.md`
- ADR log: `docs/architecture/adr/README.md`
- References: `docs/references/README.md`
