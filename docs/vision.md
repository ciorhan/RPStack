# RPStack Vision

## What RPStack is

RPStack is a modular, server-authoritative framework for serious RedM RP servers. It provides a stable core and a set of opinionated modules that can be extended without turning the server into spaghetti.

## Target users

- Server owners who want stability and long-term maintainability
- Developers who want clear boundaries and predictable APIs
- Communities that value serious RP and consistent rules

## What "game changer" means (measurable)

RPStack is considered successful if it delivers:

1. Server-authoritative economy/inventory (no client minting)
2. Clear module boundaries (no cross-module DB/table access)
3. Contract-first APIs (schema validation, versioned payloads)
4. Observability (structured logs + audit trail for key actions)
5. Developer velocity (new module can be created in under 10 minutes)

## MVP (the spine)

- Session tracking
- Character create/load/save
- Persistence layer + migrations
- Permissions skeleton (roles + policies)
- Economy skeleton (balances + transaction log)
- Structured logging and basic audit records

## Non-goals (initially)

- Full compatibility with every existing script/framework
- A complete server distribution with all gameplay systems
- Shipping every RP feature before the core is stable

## Long-term direction

- Bridge layer for script compatibility (optional, later)
- Admin tooling (audit views, action history)
- More modules: jobs, gangs, properties, crafting
- Performance-focused patterns (caching, batching, backpressure)
