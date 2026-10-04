# Local Tests and Resource Restarts

## Test layout

```text
tests/
  rpstack-factions-smoke/          guarded FXServer resource (standalone deployment)
  rpstack-vorp-bridge-smoke/       guarded FXServer resource (VORP deployment)
  rpstack-vorp-bridge-smoke-peer/  second resource used by the bridge smoke
  unit/
    factions_rank_permissions_test.lua
```

Production resources remain under `resources/`. Test-only FXServer resources live under `tests/` but retain their declared FXServer resource names.

## Resource junctions

Run `link-resources.bat` from an elevated Windows shell when setting up the local server. It targets the VORP deployment (`C:\RedMServer\txData\FrontierHegemony\resources`) and links only the resources that run there:

```text
rpstack-core, rpstack-persistence, rpstack-vorp-bridge          → C:\dev\RPStack\resources\<name>
rpstack-vorp-bridge-smoke, rpstack-vorp-bridge-smoke-peer       → C:\dev\RPStack\tests\<name>
```

`rpstack-identity`, `rpstack-economy`, `rpstack-permissions`, and `rpstack-factions` are not linked on the VORP deployment yet. The script replaces an existing smoke **junction** but refuses to replace a real directory at that path.

## VORP bridge smoke

`rpstack-vorp-bridge-smoke` and `rpstack-vorp-bridge-smoke-peer` use the same guard as the factions smoke (`set rpstack:smoke:enabled 1`). All commands are console-only and print `[SMOKE] PASS|FAIL <check> <evidence json>`. Run the money checks only against your own character; each changes the balance by $1 and restores it.

`server.cfg` (after the VORP resources):

```cfg
ensure rpstack-core
ensure rpstack-persistence
ensure rpstack-vorp-bridge
set rpstack:smoke:enabled 1
ensure rpstack-vorp-bridge-smoke
ensure rpstack-vorp-bridge-smoke-peer
```

The peer depends on the smoke resource, so it starts after it; restarting the smoke resource stops the peer, so run `start rpstack-vorp-bridge-smoke-peer` again after `restart rpstack-vorp-bridge-smoke`.

| Command | Purpose | Writes state? |
| --- | --- | --- |
| `rpstack_bridge_smoke <playerSource> [offlineCharacterId]` | N1 for an online player (compared with VORP), N1 invalid source, N2 online, N2 offline (if an offline `charidentifier` is given), N2 unknown id, N2 invalid id | No |
| `rpstack_bridge_events_smoke [playerSource]` | Prints `characterLoaded`/`characterUnloaded` events observed since the smoke started. With a source, checks a Loaded event for that source and an Unloaded event for the same character from a previous source | No |
| `rpstack_vorp_assume1 <playerSource>` | A1: a fresh `getUsedCharacter` across the export boundary reflects a $1 change; also shows whether an old snapshot goes stale | $1 then restored |
| `rpstack_vorp_assume2 <playerSource>` | A2: `GetCore().getUsers()[steamId].SaveUser()` is callable from another resource and writes the changed money to `characters.money`; then restores and saves again | $1 then restored; triggers VORP saves |
| `rpstack_vorp_assume3 <playerSource>` | A3: whether a client write to its own `Player(src).state` (smoke key `rpstackSmokeProbe`) is accepted by the server. PASS means determined; the finding is printed as INFO | Smoke state key, cleared |
| `rpstack_vorp_assume4 <playerSource>` | A4: whether `CancelEvent` in the smoke resource stops the peer resource's handler, for a local event and a client-fired net event (both smoke-owned). PASS means determined | No |
| `rpstack_vorp_assume5 <playerSource>` | A5: runs 100 same-tick check-then-`removeCurrency`/`addCurrency` pairs while a local and a peer ticker thread run; PASS if neither ticker advanced, every read matched, and money is restored | Net zero |

`rpstack-vorp-bridge` supports an independent restart: it catches up through `isPersistenceReady()` and rebuilds its source-to-character map from VORP without emitting events.

N3 procedure: start the smoke resources, connect and select a character, disconnect, reconnect and select the same character, then run `rpstack_bridge_events_smoke <newSource>`.

## Smoke guard

`rpstack-factions-smoke` is disabled unless the server convar below is set before the resource starts:

```cfg
set rpstack:smoke:enabled 1
```

All smoke commands are console-only. Keep the guard disabled outside deliberate local testing.

| Command | Purpose | Writes state? |
| --- | --- | --- |
| `rpstack_identity_smoke <playerSource>` | Lists and selects the first character, or creates one when none exists | May create/select a character |
| `rpstack_factions_smoke <characterId>` | Exercises faction creation, economy funding, treasury deposit/withdrawal, and insufficient-funds rejection | Yes |
| `rpstack_factions_state_smoke <characterId> <factionAId> <factionBId>` | Verifies hostile symmetry, online roster membership, and readable treasury balance | No |
| `rpstack_economy_callbacks_smoke <playerSource>` | Verifies five legacy asynchronous callback contracts; mutation calls intentionally use invalid zero amounts | No balance change |
| `rpstack_factions_relationship_smoke <characterId> <factionId> [secondFactionId]` | Creates or uses a second faction and sets a hostile relationship | Yes |

Bracket calls in the smoke resource deliberately pass the export proxy receiver and use ordinary Lua callback closures. This exercises the same Cfx callback adapters used by real cross-resource callers.

## Deterministic unit test

From the repository root, run:

```powershell
npx --yes --package fengari-node-cli fengari tests/unit/factions_rank_permissions_test.lua
```

The test resolves production `ranks.lua` relative to the test file, so its internal paths do not depend on the process working directory. It mocks repositories, cache updates, and audit writes while testing the real rank implementation. Rejected authorization cases assert zero inserts, updates, cache mutations, and audit writes.

## Restart ordering

Cfx stops dependent resources when a dependency is restarted, and stopped dependents are not automatically restored. Persistence emits `rpstack:persistence:ready` once. Identity, permissions, and economy initialize only from that event and do not currently check `isPersistenceReady()` when they start later.

Therefore, after restarting persistence, identity, permissions, or economy, perform a **full FXServer restart**. Starting the stopped resources manually in dependency order is not sufficient to restore all event handlers.

Factions has an explicit persistence-ready catch-up path, so a factions-only restart is supported:

```text
restart rpstack-factions
start rpstack-factions-smoke   # only when smoke testing
```

The smoke resource itself can also be restarted independently. After a full server restart, reconnect, obtain the final player source, and select the active character before running source- or roster-dependent smoke commands.
