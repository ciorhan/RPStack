# RPStack — Claude Code Context

## What this is

A modular, server-authoritative RedM roleplay framework. Core + modules model. Greenfield — no FiveM carryover. Loose VORP/RSG export compatibility is a goal.

## Stack

- Runtime: RedM / Cfx.re (CfxLua, Lua 5.4)
- DB: oxmysql + MySQL/MariaDB
- NUI: plain HTML/CSS/JS (no build step)
- No ox_lib dependency in v0

## Resource layout

```
resources/
  rpstack-core/         config, logger, service registry, errors
  rpstack-persistence/  oxmysql wrapper, migration runner
  rpstack-identity/     accounts, sessions, multi-character
  rpstack-economy/      cash + bank balances, transaction log
```

Load order must follow this sequence. Each resource declares `dependency` in its fxmanifest.

## Architecture rules (non-negotiable)

1. Client requests. Server decides. No exceptions.
2. Every state-changing server function validates: type, range, ownership, permissions.
3. Modules own their DB tables. No cross-module table access. Use exports.
4. Public exports follow `rpstack:<module>:<action>` naming.
5. Network events follow `rpstack:<module>:<event>` naming.
6. Never trust: source, payload values, entity ownership, positions from client.
7. Always capture `local src = source` immediately in event handlers — never defer it.
8. No global mutable state without explicit ownership and lifecycle documentation.

## Identity model

- Primary identifier: `license2 → license → fivem` fallback chain
- Internal key: `account_id` (DB auto-increment) — all cross-module references use this
- Sessions are in-memory. Accounts and characters are persisted.

## Security invariants

- Deferrals used for connection screening (ban check before player joins)
- RPC layer rate-limits per source per route
- Economy operations go through the ledger — never direct balance mutation
- Audit log entries for: money changes, character create/delete, role changes

## Commands (run from repo root)

```bash
# No build step. Lua files are loaded directly by the Cfx runtime.
# Linting (when configured):
luacheck resources/ --config .luacheckrc
```

## Definition of done (per task)

- [ ] Server-authoritative (no client trust)
- [ ] Input validated (type, range, ownership)
- [ ] Structured log entry for state changes
- [ ] Export/event follows naming convention
- [ ] fxmanifest load order correct
- [ ] No cross-module DB access

## Key docs

- Architecture: `docs/architecture/overview.md`
- Security: `docs/security/threat-model.md`
- Creating a resource: `docs/development/creating-a-resource.md`
- ADR log: `docs/architecture/adr/README.md`
- References: `docs/references/README.md`
