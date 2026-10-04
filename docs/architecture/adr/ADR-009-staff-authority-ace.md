# ADR-009: Staff authority is ACE only

Date: 2026-10-04
Status: Accepted

## Decision

RPStack staff and administrative checks use ACE only, through `IsPlayerAceAllowed(source, 'rpstack.<module>.<permission>')`. RPStack never trusts VORP `users.group` or `characters.group` for authorization.

## Reasoning

VORP groups live in the database and can be changed by any holder of the `set_group` action, including moderators (`vorp_admin/server/server.lua:525-547`; `vorp_admin/config.lua:203`). VORP also assigns `admin` to the first account ever created (`vorp_core/server/loadusers.lua:170-171`). ACE is controlled from server configuration, which only server operators can change.

## Consequences

Easier: one auditable source of staff authority, independent of VORP data.
Harder: staff must be granted ACE principals in `server.cfg`; VORP's own commands still follow VORP group checks.
