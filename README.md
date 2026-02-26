# RPStack

RPStack is a modern, server-authoritative RedM roleplay framework focused on security, stability, and scalability. It provides a modular foundation with clean APIs, consistent patterns, and performance-minded design for building serious RP servers that can grow from MVP to high concurrency.

## Why RPStack

Most RedM servers end up as a pile of loosely-coupled scripts held together by implicit events and shared state. RPStack aims to fix that with:

- **Server-authoritative core systems** (money/items/permissions validated on the server)
- **Modular architecture** (features are modules, not spaghetti resources)
- **Contract-first APIs** (predictable interfaces between modules and scripts)
- **Production-minded tooling** (logging, auditing, migrations, structured configs)

If you want a long-term codebase that can keep evolving without rewrites, this is the direction.

---

## Goals

- Clean, consistent foundations for common RP systems:
  - identity & character
  - permissions & policies
  - persistence & migrations
  - economy (ledger-ready) & transactions
  - inventory (server authoritative)
- Strong conventions for:
  - resource boundaries and module ownership
  - event validation and trust boundaries
  - structured logging and audit trails
- DX that makes it easy to build custom gameplay modules fast.

## Non-goals (at least for v0)

- Be “compatible with everything” out of the box.
- Include every RP feature on day one.
- Ship a full server distribution (RPStack is a framework, not a full server).

---

## Architecture (high level)

RPStack is designed around a **core + modules** model.

- **Core** provides:
  - lifecycle and module loading
  - configuration & environment handling
  - logging and diagnostics
  - a stable API surface (exports/contracts)

- **Modules** provide gameplay systems:
  - identity (player/character/session)
  - permissions (roles/policies)
  - persistence (DB adapters, migrations, repositories)
  - economy (accounts/ledger/transactions)
  - inventory (items, containers, transactions)

### Trust boundary rule

**Clients request. Server decides.**  
Any action that changes money, items, permissions, or character state must be validated and applied on the server.

---

## Repository layout (planned)

rpstack/
docs/ # documentation and design notes
resources/
rpstack-core/ # core runtime, logging, config, contracts
rpstack-identity/ # sessions, characters, identity
rpstack-permissions/ # roles, policies, authz checks
rpstack-persistence/ # db adapters, migrations, repository layer
rpstack-economy/ # accounts, transactions, audit trail
rpstack-inventory/ # items, containers, server-authoritative ops
tools/ # dev tooling (linting, generators, etc.)
scripts/ # helper scripts (bootstrap, export, etc.)

---

## Roadmap

### v0 — The Spine (minimal but real)

- Player connect/session tracking
- Character create/load/save
- Persistence layer with migrations
- Permissions skeleton (roles + policy checks)
- Economy skeleton (server-side balance + transaction log)
- Structured logs + basic audit trail

### v1 — Core RP primitives

- Inventory (server authoritative)
- Basic shops/transactions
- Admin tooling hooks (audit queries, moderation hooks)

### v2 — Gameplay modules

- Jobs/gangs
- Housing/properties
- Advanced economy (ledger, taxes, sinks/sources)

---

## Development principles

- **Modules own their data**: no random cross-table access.
- **Exports/contracts over random events**: predictable APIs, fewer breaking changes.
- **Validate inputs**: don’t trust payloads from client or other scripts.
- **Observe everything**: logs and audit trails are features, not extras.
- **Ship small, iterate**: build vertical slices, not giant rewrites.

---

## Status

Early stage: research + architecture + initial spine.

If you're interested in contributing, open an issue with:

- what module you want to work on
- what experience you have with RedM/FiveM scripting
- what problem you want RPStack to solve for your server

---

## License

TBD (recommendation: start with MIT for maximum adoption, revisit if needed).
