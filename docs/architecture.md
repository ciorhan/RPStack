# RPStack Architecture

## Core idea

RPStack is built as core + modules. Core provides runtime, logging, config, and contracts. Modules provide gameplay systems behind stable APIs.

## Layers (mental model)

- API/Contracts layer: exports and events (namespaced, versioned)
- Domain layer: business rules (server-authoritative)
- Infrastructure: DB adapters, caching, IO
- Client: UI and local presentation only

## Trust boundaries

- Client is untrusted.
- Server validates everything.
- "State-changing commands" live on server and are audited.

## Communication patterns

Prefer:

1. exports (stable, direct)
2. internal service registry (core-managed)
   Use events only when needed for pub/sub, and always namespace them:
   `rpstack:<module>:<event>`

## Contracts

Every public API should define:

- input schema
- output schema
- error codes

Even if you do not implement a full type system on day one, keep schemas in `shared/contracts/`.

## Data ownership

Each module owns:

- its tables/collections
- its migrations
- its repositories

Cross-module calls must use exports/contracts, not direct DB access.

## Observability

- Structured logging with categories and correlation ids
- Audit log for critical actions:
  - money changes
  - inventory changes
  - role/permission changes
  - character creation/deletion
