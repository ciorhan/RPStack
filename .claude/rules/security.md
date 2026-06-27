# Security Rules

## Trust boundary

- Client is untrusted. Always.
- Server validates everything before acting: type, range, ownership, cooldown, permissions.
- Never use a value from a client payload as a DB key without validation.
- Never expose internal account_id or DB row structure in client-facing events.

## Identifiers

- Primary identifier resolved server-side only: `license2 → license → fivem`.
- Never accept an identifier string from the client. Resolve from `GetPlayerIdentifier`.
- `account_id` (internal DB integer) is the only cross-module reference. Never send to client.

## Network events

- All `RegisterNetEvent` handlers must validate source immediately.
- Rate-limit all client-triggered events and RPC calls.
- Never `TriggerEvent` (local) with data that came from a client without sanitizing first.

## Economy

- Balance reads: allowed server-side freely.
- Balance mutations: only through the ledger function. Never direct DB update outside economy module.
- All transactions logged with: source account, dest account, amount, reason, timestamp, acting_source.

## Deferrals

- Use `playerConnecting` with deferrals for ban checks before player enters session.
- Log every deferral rejection with identifier and reason.

## Audit log targets (mandatory)

- Character create / delete
- Money in / out (any amount)
- Permission / role changes
- Admin actions

## What to check on every PR / task

- [ ] No client payload used as DB key directly
- [ ] No balance mutation outside ledger
- [ ] Rate limit applied to new RPC/event
- [ ] Audit log entry for state-changing actions
- [ ] `local src = source` captured before any yield
