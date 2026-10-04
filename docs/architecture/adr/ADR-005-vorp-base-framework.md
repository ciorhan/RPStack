# ADR-005: VORP Core is the base framework

Date: 2026-10-04
Status: Accepted

## Decision

Frontier Hegemony runs on VORP Core (txAdmin VORP recipe, pinned versions). VORP owns connection, accounts, characters, character creation and selection, spawn, character money, inventory, and jobs. RPStack provides gameplay modules on top of VORP. `rpstack-core` and `rpstack-persistence` stay. `rpstack-identity` and `rpstack-permissions` do not run on VORP deployments. `rpstack-vorp-bridge` is the only RPStack resource that calls VORP APIs; other RPStack modules reach VORP data through the bridge.

## Reasoning

VORP already provides a playable connect-to-spawn flow, an integrated appearance creator, inventory, and a large gameplay catalogue. Rebuilding those before First Arrival would delay the product without a matching benefit. Concentrating VORP calls in one bridge keeps RPStack modules portable and gives one place to enforce the trust rules in ADR-011. See `docs/integration/vorp-analysis.md` §7.

## Consequences

Easier: playable server today, faster First Arrival, existing VORP content.
Harder: VORP's data model (Steam-keyed accounts, float money, in-memory balances) and its security defects become constraints RPStack must work around (ADR-006, ADR-007, ADR-008, ADR-011).
