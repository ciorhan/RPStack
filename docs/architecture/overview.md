# Architecture Overview

## Model

RPStack is built as **core + modules**. Core provides the runtime foundation. Modules provide gameplay systems behind stable exports. Modules never reach into each other's internals or tables.

## Resources and responsibilities

```text
rpstack-core
  Config, structured logger, service registry, and shared error codes.
  No gameplay logic or DB access.

rpstack-persistence
  oxmysql wrapper, migration runner, and DB connectivity check.
  Exposes dbQuery, dbSingle, dbExecute, dbInsert, and migration registration.
  Fires rpstack:persistence:ready after all registered migrations complete.

rpstack-identity
  Accounts, connection sessions, and multi-character ownership.
  Owns rpstack_accounts and rpstack_characters.

rpstack-permissions
  Account roles, permission cache, and superadmin bypass.
  Owns rpstack_roles, rpstack_role_permissions, and rpstack_account_roles.

rpstack-economy
  Character balances and generic owner accounts for systems such as factions.
  Owns rpstack_economy_accounts and rpstack_economy_transactions.

rpstack-factions
  Factions, membership, ranks, relationships, audit history, and treasuries.
  Owns all rpstack_faction* tables. Uses public economy exports for balances.
```

## Dependency and load graph

```text
rpstack-core
  └── rpstack-persistence
        └── rpstack-identity
              ├── rpstack-permissions
              └── rpstack-economy
                    └── rpstack-factions
```

The manifests also declare direct dependencies where required; for example, factions declares core, persistence, identity, and economy. The optional `rpstack-factions-smoke` test resource depends on identity, economy, and factions.

## Startup and migrations

1. System resources and oxmysql start.
2. RPStack resources load in dependency order and register migrations at the top level of their `server/main.lua` files.
3. Persistence yields for a bounded number of ticks, verifies the DB connection, and runs the migrations registered by that point. There is no registration-complete handshake.
4. Persistence emits `rpstack:persistence:ready`.
5. Module ready handlers initialize their caches and event handlers.

Merged main currently registers **18 module migrations**:

| Module | Count | Purpose |
| --- | ---: | --- |
| identity | 2 | accounts and characters |
| permissions | 3 | roles, permission definitions, and account-role assignments |
| economy | 7 | character accounts, transactions, owner-account columns/indexes, and owner backfills |
| factions | 6 | factions, ranks, members, relationships, audit log, and unique rank levels |

Migration names are stable identifiers. Existing installations progress through the owner-account alterations and backfills; they do not recreate economy tables from scratch.

## Resource isolation

CfxLua gives each resource an isolated Lua environment. Globals do not cross resource boundaries. Every resource that needs logging, DB access, or error constants loads its own shared implementation.

## Export invocation and callbacks

Export names follow the convention of the resource that owns them. Persistence and factions currently use simple names; identity and economy include namespaced names. Callers must not rewrite an existing public name to fit a global naming rule.

Colon syntax supplies the Cfx export proxy receiver automatically when the export name is a valid Lua identifier:

```lua
exports['rpstack-persistence']:registerMigration(name, sql)
```

Bracket syntax must pass the proxy explicitly as the first argument. This works for simple and namespaced exports:

```lua
local factions = exports['rpstack-factions']
factions['createFaction'](factions, payload, callback)

local economy = exports['rpstack-economy']
economy['rpstack:economy:getBalance'](economy, source, callback)
```

Cross-resource callbacks arrive at the callee as Cfx function references. In verified runtime calls their Lua type was `table`, not `function`. Identity, economy, and factions adapt these references before passing them to domain code:

```lua
local function localCallback(callback)
  if callback == nil then return nil end
  return function(result)
    callback(result)
  end
end

exports('someAsyncExport', function(payload, callback)
  DOMAIN.someAsyncOperation(payload, localCallback(callback))
end)
```

Domain functions retain strict `type(callback) == 'function'` validation because they receive the adapted local closure. Do not validate a raw cross-resource callback as a native function at those export boundaries. Persistence's infrastructure-level DB proxy exports are a separate pass-through: they currently forward callbacks directly to `RPSTACK_DB`.

## Player lifecycle and source migration

```text
playerConnecting (temporary source, with deferrals)
  → identity resolves license2 → license → fivem
  → account is found or created
  → session is stored under the temporary source
  → deferrals.done()

playerJoining (final source; oldSrc is the temporary source)
  → identity removes sessions[oldSrc]
  → session.source is replaced with the final source
  → session is stored under the final source
  → rpstack:identity:sessionCreated(finalSource, accountId) is emitted
  → permissions loads the account cache using the final source

character selection
  → identity verifies character ownership
  → activeCharacterBySource[finalSource] is populated
  → characterCreated is emitted for a newly created character
  → economy creates its default character account

playerDropped
  → character and session lifecycle events are emitted with the final source
  → permissions and identity caches are cleared
```

Never persist or assume a player source, and never assume it is `1`. Commands and source-based exports must use the final runtime source observed after `playerJoining`.

## Economy owner accounts

`rpstack_economy_accounts` supports both characters and non-character owners:

| Field | Meaning |
| --- | --- |
| `char_id` | Legacy character link; nullable for non-character owners |
| `owner_type` | `character`, `faction`, or another validated owner token |
| `owner_id` | Identifier within the owner type |
| `account_type` | `default`, `treasury`, or another validated account token |
| `cash`, `bank` | Stored balances |

The economy migrations add owner fields and indexes, backfill character account owners, extend transaction ownership fields, and backfill legacy character transactions. The unique owner/account index prevents duplicate accounts for the same `(owner_type, owner_id, account_type)` tuple.

Character cash/bank adjustments use `RPSTACK_LEDGER.apply`. Generic single-owner adjustments use `RPSTACK_ECONOMY_ACCOUNTS.adjustOwnerCash`. Cross-owner movements use `transferCash`, whose single conditional SQL update debits and credits both accounts atomically and rejects insufficient source funds. After the balance update, economy asynchronously inserts owner transaction records for both sides and logs an error if either audit insert fails; an audit failure does not roll back the completed transfer.

## Faction rank authorization

Higher numeric rank levels have greater authority. Rank levels are unique within a faction.

Creating or updating a rank requires `can_promote`. The actor may create or modify only ranks strictly below their own level, may not modify their own assigned rank, and may not modify an equal or higher rank. The resulting level must also remain strictly below the actor's level.

Rank payload fields are allowlisted. Permission values must be booleans, and every enabled permission on the resulting rank must also be enabled on the actor's rank. Updates preserve omitted permission values, including explicit `false` values. These rules prevent self-escalation and permission delegation beyond the actor's authority; the founder's top-rank position is protected by the same strict hierarchy.

## Faction treasury

Faction creation provisions an economy owner account with `owner_type='faction'`, `owner_id=factionId`, and `account_type='treasury'`. If treasury provisioning fails, faction creation follows its failure cleanup path.

Deposits require `can_deposit` and atomically move cash from the character's `default` owner account to the faction treasury. Withdrawals require `can_withdraw` and move cash in the opposite direction. Amounts and notes are validated, optional configured limits are enforced, and transfers are serialized per faction with a bounded lock wait.

After a successful balance transfer, economy attempts transaction audit inserts for both owners, factions attempts its treasury audit insert, and factions emits `rpstack:factions:treasuryChanged`. These audit writes are asynchronous and do not roll back the transfer if they fail. Treasury balance reads use the public economy owner-account export. Factions never update economy tables directly.

## Data ownership

| Table | Owner |
| --- | --- |
| `rpstack_accounts` | rpstack-identity |
| `rpstack_characters` | rpstack-identity |
| `rpstack_roles` | rpstack-permissions |
| `rpstack_role_permissions` | rpstack-permissions |
| `rpstack_account_roles` | rpstack-permissions |
| `rpstack_economy_accounts` | rpstack-economy |
| `rpstack_economy_transactions` | rpstack-economy |
| `rpstack_factions` | rpstack-factions |
| `rpstack_faction_ranks` | rpstack-factions |
| `rpstack_faction_members` | rpstack-factions |
| `rpstack_faction_relationships` | rpstack-factions |
| `rpstack_faction_audit_log` | rpstack-factions |
| `_rpstack_migrations` | rpstack-persistence |

## Operations and tests

See [Local Tests and Resource Restarts](../development/testing.md) for the `tests/` layout, junction setup, smoke guard and commands, deterministic unit test, and restart ordering.

## Error codes

| Code | Meaning |
| --- | --- |
| `VALIDATION_FAILED` | Bad input |
| `NOT_AUTHORIZED` | Permission denied or ownership mismatch |
| `NOT_FOUND` | Entity does not exist |
| `CONFLICT` | Duplicate or state conflict |
| `INTERNAL` | Unexpected server error |

## Key ADRs

- [ADR-001](adr/README.md) — internal `account_id` decoupled from Cfx identifiers
- [ADR-002](adr/README.md) — no ox_lib in v0
- [ADR-003](adr/README.md) — oxmysql with MySQL/MariaDB
- [ADR-004](adr/README.md) — multi-character from v0
