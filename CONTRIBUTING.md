# Contributing to RPStack

Thanks for contributing. RPStack aims to be modular, stable, and server-authoritative.

## Principles

- Clients request. Server decides.
- Modules own their data. No cross-module DB/table access.
- Prefer exports/contracts over ad-hoc events.
- Validate all inputs (client and server).
- Observability is a feature: logs and audits matter.

## Repo conventions

- Each module lives in `resources/rpstack-<module>/`
- Code split:
  - `server/` server-only logic (authoritative)
  - `client/` client-only logic (UI, input, local helpers)
  - `shared/` shared constants, types, schemas
- Configuration:
  - `config/default.json` with sane defaults
  - allow overrides via server convars/env where possible

## Coding standards

- Keep functions small and single-purpose.
- Avoid global mutable state. Prefer services registered in core.
- Name exports with `rpstack:<module>:<action>` pattern.
- Avoid random event names. If you must use events, namespace them:
  - `rpstack:<module>:<event>`

## Security checklist (must)

- Never trust client payloads.
- Any economy/inventory change must be server-side and validated.
- Enforce permissions via policy checks.
- Log important state changes (money/items/roles).

## Testing

- Add small unit-style tests where possible (helpers, validation).
- Add integration tests for critical flows when tooling exists.

## Commit messages

Use:

- `feat(module): ...`
- `fix(module): ...`
- `docs: ...`
- `chore: ...`
- `refactor(module): ...`

Examples:

- `feat(core): add structured logger`
- `fix(economy): prevent negative withdrawals`

## Pull requests

PRs should include:

- What changed and why
- Any breaking changes
- How to test manually
- Screenshots/log output if relevant
