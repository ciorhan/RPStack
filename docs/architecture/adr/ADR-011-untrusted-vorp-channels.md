# ADR-011: Untrusted VORP channels

Date: 2026-10-04
Status: Accepted

## Decision

RPStack never treats any of these as proof of identity, ownership, consent, or state:

- VORP RPC callbacks (`vorp:TriggerServerCallback`, `vorp:ServerCallback`, `Core.Callback.*`)
- player state bags (`Player(src).state`, including `Character`)
- the `vorp_NewCharacter` event
- the `vorp:ImDead` death flag

RPStack resolves facts from VORP server objects fetched fresh at the time of use (for example `GetCore().getUser(src).getUsedCharacter`) and from its own tables. RPStack client entry points use RPStack net events with validation and rate limits, not VORP callbacks.

## Reasoning

- Any client can replace registered VORP callbacks and resolve other players' pending callbacks (`vorp_core/server/class/callbacks.lua:118-141`).
- State bags are replicated and may be client-writable.
- `vorp_NewCharacter` can be re-fired through repeated character creation (`vorp_character/server/server.lua:122-131`).
- `vorp:ImDead` is set directly by the client (`vorp_core/server/loadcharacter.lua:24-34`).

See `docs/integration/vorp-analysis.md` §6.

## Consequences

Easier: RPStack security does not depend on VORP fixing these channels.
Harder: RPStack must re-derive state server-side and cannot reuse VORP's callback helper.
