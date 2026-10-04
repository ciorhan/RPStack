# ADR-006: VORP Steam identity and charidentifier as keys

Date: 2026-10-04
Status: Accepted. Supersedes ADR-001 for VORP deployments.

## Decision

On VORP deployments, the account identity is VORP's Steam hex identifier (`users.identifier`), resolved server-side by VORP. RPStack does not create its own account table or `account_id`. The cross-module character key everywhere in RPStack is VORP's `characters.charidentifier` (integer, auto-increment, never reused). RPStack tables reference characters by this integer and never store Steam identifiers as foreign keys.

## Reasoning

VORP requires Steam at connect (`vorp_core/server/whitelist.lua:46-53`) and keys all users by the Steam identifier (`vorp_core/server/loadusers.lua:152-175`). A parallel RPStack account table keyed by `license2` would duplicate identity, drift from VORP's view, and add a lookup with no consumer, because RPStack modules work at character level. `charidentifier` is a stable integer, which keeps the intent of ADR-001 (integer keys, no Cfx identifier strings as foreign keys) at the level RPStack actually needs.

## Consequences

Easier: one identity source, no account synchronization, simple integer foreign keys.
Harder: account-level features (bans, character limits) follow VORP's Steam-only model. A future non-Steam platform change in VORP would need its own migration. ADR-001 remains in force for non-VORP deployments.
