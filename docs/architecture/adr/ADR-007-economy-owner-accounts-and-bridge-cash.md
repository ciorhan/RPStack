# ADR-007: Slim economy to owner accounts; bridge performs character cash

Date: 2026-10-04
Status: Accepted (implementation pending)

## Decision

On VORP deployments `rpstack-economy` no longer stores character balances. It is slimmed to owner accounts (for example faction treasuries), the transaction ledger, and a transfer journal. Character cash lives only in VORP. `rpstack-vorp-bridge` exposes VORP character cash debit and credit; only economy calls them. Transfers between a character and an owner account are journaled sagas (`docs/integration/vorp-analysis.md` §8 N5). `rpstack-factions` keeps calling the existing `rpstack:economy:*` exports unchanged.

## Reasoning

VORP keeps character money in vorp_core memory and flushes it on a timer (`vorp_core/server/class/character.lua:366-393, 497-528`; `vorp_core/config/config.lua:71`), so a single SQL statement cannot move money atomically between a character and an RPStack account. Keeping the ledger and journal in economy preserves module ownership (economy owns every RPStack balance mutation) and leaves factions untouched.

## Consequences

Easier: factions needs no change; one ledger for all RPStack money movements; idempotent, auditable transfers.
Harder: transfers are sagas with compensation, not single atomic statements. Durability of the character side depends on VORP's save behaviour, which the bridge smoke checks verify.
