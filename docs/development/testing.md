# Local Tests and Resource Restarts

## Test layout

```text
tests/
  rpstack-factions-smoke/          guarded FXServer resource
  unit/
    factions_rank_permissions_test.lua
```

Production resources remain under `resources/`. Test-only FXServer resources live under `tests/` but retain their declared FXServer resource names.

## Resource junctions

Run `link-resources.bat` from an elevated Windows shell when setting up the local server. It creates junctions from the FXServer resource directory to every `resources/rpstack-*` directory. It also maintains this explicit test junction:

```text
C:\RedMServer\FrontierHegemony\resources\rpstack-factions-smoke
  → C:\dev\RPStack\tests\rpstack-factions-smoke
```

The script replaces an existing smoke **junction** but refuses to replace a real directory at that path.

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
