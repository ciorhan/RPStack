# Architecture Overview

## Model

RPStack is built as **core + modules**. Core provides the runtime foundation. Modules provide gameplay systems behind stable, versioned APIs. Modules never reach into each other's internals.

## Resources and responsibilities

```
rpstack-core
  Config (convars), structured logger, service registry, shared error codes.
  No gameplay logic. No DB access.

rpstack-persistence
  oxmysql wrapper, migration runner, DB connectivity check.
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
```

## Load order

```
rpstack-core
  └── rpstack-persistence
        └── rpstack-identity
              └── rpstack-economy
```

Enforced by `dependency` declarations in each fxmanifest. The Cfx runtime guarantees a resource's dependencies are started before it.

## Startup sequence

```
1. rpstack-core loads        — logger and config available
2. rpstack-persistence loads — registers DB wrapper
3. rpstack-identity loads    — registers migrations (001, 002)
4. rpstack-economy loads     — registers migrations (001, 002)
5. rpstack-persistence:main  — pings DB, waits one tick, runs all migrations
6. rpstack:persistence:ready fires
7. rpstack-identity:main     — registers playerConnecting + playerDropped
8. rpstack-economy:main      — registers characterCreated listener
```

## Player lifecycle

```
playerConnecting
  → identity resolves identifier (license2 → license → fivem)
  → DB lookup: find or create account
  → session created in memory
  → deferrals.done() — player enters server

character selection (client-triggered, server-validated)
  → getCharacters → player sees their characters
  → selectCharacter(char_id) → server verifies ownership
  → activeCharacterBySource[src] = character

playerDropped
  → session cleared
  → activeCharacterBySource cleared
```

## Communication patterns

**Exports** — primary pattern for cross-resource calls. Synchronous call, async result via callback.

```lua
exports['rpstack-economy']['rpstack:economy:addMoney'](src, "cash", 100, "job_payment", function(result)
  if result.ok then ... end
end)
```

**Internal events** — used for loose coupling within the framework (e.g. `rpstack:identity:characterCreated`). Never used as a substitute for exports in cross-module reads.

**Network events** — client → server only for requests. Server → client for responses. Always namespaced `rpstack:<module>:net:<event>`. Rate-limited.

## Trust boundary

```
Client          →   untrusted. Sends requests only.
Server exports  →   trusted. Validate all inputs. Own all state.
DB              →   trusted. Parameterized queries only.
```

No client payload is used as a DB key or balance value without server-side validation.

## Data ownership

| Table                          | Owner               |
| ------------------------------ | ------------------- |
| `rpstack_accounts`             | rpstack-identity    |
| `rpstack_characters`           | rpstack-identity    |
| `rpstack_economy_accounts`     | rpstack-economy     |
| `rpstack_economy_transactions` | rpstack-economy     |
| `_rpstack_migrations`          | rpstack-persistence |

Cross-module data access uses exports only. No resource queries another's tables.

## Error codes (shared)

Defined in `rpstack-core/shared/errors.lua`:

| Code                | Meaning                                 |
| ------------------- | --------------------------------------- |
| `OK`                | Success                                 |
| `VALIDATION_FAILED` | Bad input (type, range, format)         |
| `NOT_AUTHORIZED`    | Permission denied or ownership mismatch |
| `NOT_FOUND`         | Entity does not exist                   |
| `CONFLICT`          | Duplicate or state conflict             |
| `INTERNAL`          | Unexpected server error                 |

## Key ADRs

- [ADR-001](adr/README.md) — Internal account_id decoupled from Cfx identifiers
- [ADR-002](adr/README.md) — No ox_lib in v0
- [ADR-003](adr/README.md) — oxmysql + MySQL/MariaDB only
- [ADR-004](adr/README.md) — Multi-character from v0
