# Architecture Rules

## Module ownership

- Each resource owns: its DB tables, its migrations, its in-memory state.
- Cross-module reads: use exports only.
- Cross-module writes: never. The owning module exposes a write API via export.

## Export contract shape

Every export returns `{ ok = boolean, data|error = ... }`. No exceptions.
Exports are named `rpstack:<module>:<action>`. Example: `rpstack:identity:getSession`.

## Event naming

Internal (server-only, never net): `rpstack:<module>:<event>` via `TriggerEvent`.
Network (server↔client): `rpstack:<module>:net:<event>` via `TriggerNetEvent` / `TriggerServerEvent`.

## Load order (enforced by fxmanifest dependencies)

```
rpstack-core
  └── rpstack-persistence
        └── rpstack-identity
              └── rpstack-economy
```

## Startup contract

Each resource must:

1. Load config
2. Register services with `RPSTACK_SERVICES`
3. Run migrations (persistence-dependent resources only)
4. Log `"<module> ready"` when initialization is complete
5. Only then register net event handlers

## Restart behavior

- Resources must handle restart gracefully: re-register services, re-run pending migrations (idempotent).
- In-memory state is lost on restart — persistence layer must rebuild necessary state on load.

## What goes where

| Concern                        | Location                                   |
| ------------------------------ | ------------------------------------------ |
| Config values                  | `config/server.lua` (convars)              |
| Shared constants / error codes | `shared/`                                  |
| Business logic                 | `server/`                                  |
| DB queries                     | `server/repositories/`                     |
| Public API surface             | `server/exports.lua`                       |
| Net event handlers             | `server/main.lua` or `server/handlers.lua` |
| Client UI only                 | `client/`                                  |
