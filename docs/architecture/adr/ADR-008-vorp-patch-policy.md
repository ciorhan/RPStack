# ADR-008: VORP pinning and patch policy

Date: 2026-10-04
Status: Accepted

## Decision

VORP resources are pinned to known versions and are not auto-updated. Changes to VORP files are limited to security guard clauses and config edits, kept as a numbered patch series that is re-applied on every upgrade. VORP money surfaces with client-trusted amounts (`vorp_stores`, `vorp_banking`, `vorp_billing`, `vorp_weaponsv2`) are disabled and will be replaced by RPStack modules rather than patched. `vorp_admin` is disabled; txAdmin provides staff tools. RPStack code never edits VORP files at runtime.

A "shield" resource that calls `CancelEvent` to block VORP net handlers is rejected. The live check was inconclusive (the other resource's handler ran first), and even if `CancelEvent` did stop other resources' handlers, the protection would depend on handler order across resources, which RPStack does not control. Security fixes go through the patch series (`docs/integration/vorp-analysis.md` §10, §11 A4).

## Reasoning

The analysis found client-driven minting and authorization gaps (`docs/integration/vorp-analysis.md` §6). Some are in resources that cannot be removed (vorp_core, vorp_inventory, vorp_character), so minimal guard clauses are unavoidable. Rewriting VORP money resources would turn the patch series into a fork; replacing them with RPStack modules keeps it small and reviewable.

## Consequences

Easier: VORP upgrades are deliberate and diffable; disabling resources shrinks the attack surface immediately.
Harder: the patch series needs maintenance on each upgrade; stores, banking, billing, and weapon customization are unavailable until RPStack replacements exist.
