# VORP Analysis and RPStack Mapping

## Status

Analysis only. Nothing in the server folder or the RPStack code was changed. Date: 2026-10-04. Runtime verification results added in §11.

## Scope and conventions

- **Server:** `C:\RedMServer\txData\FrontierHegemony` (txAdmin VORP Core recipe, build 1491, oxmysql, MariaDB 13.0.2, database `rpstack`).
- **Citations:**
  - Paths without a prefix are relative to `C:\RedMServer\txData\FrontierHegemony\resources\[VORP]\`.
  - `server.cfg` means `C:\RedMServer\txData\FrontierHegemony\server.cfg`.
  - Paths that start with `resources/rpstack-*`, `docs/` or `.claude/` are relative to the RPStack repo root.
- **Verification:**
  - Every API, event, and table was read from source or from the live schema.
  - Line numbers come from the files as deployed.
  - **[inferred]** marks a conclusion drawn from code behavior that was not exercised at runtime.
  - **[verified]** / **[refuted]** mark a former inference that a live smoke run confirmed or disproved (see "Runtime verification"). **[inconclusive]** marks one the run could not decide.
- **Database access:** two read-only operations:
  - `mariadb-dump --no-data` (schema only, written to a scratch folder outside both trees).
  - `SELECT COUNT(*)` style row counts.
  - No writes.
- **Not reproduced here:** `server.cfg` contains a plaintext license key, Steam Web API key, and DB credentials (`server.cfg:14`, `:18`, `:19`). The values are intentionally left out of this report (see Top 5 risks).

---

## 1. RPStack values (the yardstick)

| # | Invariant | Source |
| --- | --- | --- |
| V1 | **Client requests, server decides.** Every state-changing handler validates type, range, ownership, permissions, and cooldown. Never trust source, payload values, entity ownership, or positions from the client. | `CLAUDE.md` "Architecture rules" 1, 2, 6; `.claude/rules/security.md` |
| V2 | **Rate-limit** every client-triggered event and RPC. Capture `local src = source` before any yield. | `.claude/rules/security.md`; `CLAUDE.md` rule 7 |
| V3 | **Module ownership.** Each module owns its tables, migrations, and in-memory state. Cross-module reads and writes go through exports only. No cross-module table access. | `.claude/rules/architecture.md`; `docs/architecture/overview.md` "Data ownership" |
| V4 | **Economy owns every balance mutation** through a ledger. Amounts are positive bounded integers. Cross-owner moves are atomic (one conditional SQL update). Every transaction is logged with source, destination, amount, reason, time, and actor. | `docs/security/threat-model.md` §3; `docs/architecture/overview.md` "Economy owner accounts" |
| V5 | **Audit** money in/out, character create/delete, role changes, and admin actions. | `CLAUDE.md` "Security invariants"; `.claude/rules/security.md` |
| V6 | **Identity:** `license2 → license → fivem` is resolved server-side. The internal integer `account_id` is the only cross-module key. Cfx identifier strings are never used as foreign keys. | `CLAUDE.md` "Identity model"; `.claude/rules/database.md`; ADR-001 |
| V7 | **Naming:** tables `rpstack_*`. Events `rpstack:<module>:<event>` (internal) and `rpstack:<module>:net:<event>` (network). Exports follow the owning module's convention; bracket calls pass the proxy receiver. | `CLAUDE.md` "Table naming", "Export patterns"; `.claude/rules/architecture.md` |
| V8 | **Export contract:** `{ ok, data \| error }`. Sync for cache reads, async with callback for DB/economy. Cross-resource callbacks must be adapted (they arrive as tables). | `CLAUDE.md` items 2–4; `docs/architecture/overview.md` "Export invocation and callbacks" |
| V9 | **Product:** creation rewards exactly once. Client-provided identity, appearance, and spawn data are requests. Destructive actions need server authorization. Interrupted creation is resumable without duplicates. | `docs/product/first-arrival.md` "Experience constraints" |
| V10 | **Vision KPI #1:** server-authoritative economy and inventory, "no client minting". | `docs/vision.md` |

Note: `.claude/rules/redm.md` ("Export names must be simple strings… no namespacing") contradicts `CLAUDE.md` and `docs/architecture/overview.md`, which document namespaced economy and identity exports. `.claude/rules/architecture.md` also says all exports are `rpstack:<module>:<action>`, which persistence and factions do not follow. Worth reconciling before new adapter code is written.

---

## 2. Server inventory

### 2.1 server.cfg

- Runs on build 1491 (`server.cfg:16`) with oxmysql pointed at DB `rpstack` (`server.cfg:19`) and `sv_maxclients 48` (`server.cfg:15`).
- Server locale is `ro-RO` (`server.cfg:28`); the VORP `Lang` is `"English"` (`vorp_core/config/config.lua:5`).
- Load order (`server.cfg:36-96`):
  1. **Base:** mapmanager, chat, spawnmanager, redm-map-one, hardcap, pma-voice, loadingscreen.
  2. **Dependencies:** oxmysql, weathersync, redm-ipls, syn_minigame, lockpick, PolyZone, moonshine_interiors, vorp_menu, female_body_fix, vorp_lib.
  3. **Permission files:** `exec weathersync/permissions.cfg` and `exec vorp_admin/vorp_perms.cfg` (`:59-60`).
  4. **VORP:** vorp_core → inputs → progressbar → inventory → character → utils (marked deprecated) → admin → metabolism → doorlocks → barbershop → postman → hunting → stables → weaponsv2 → stores → fishing → crawfish → herbs → housing → banking → mailbox → walkanim → police → crafting → zonenotify → mining → lumberjack → animations → outlaws → medic → billing → paycheck → wildhorse → lootnpcs.
- **ACE** (`server.cfg:100-109`):
  - `group.admin` gets `command` (all commands except `quit`).
  - `resource.vorp_lib` may run `add_ace` / `remove_ace`.
  - The owner is added to `group.admin` through `identifier.fivem:` and `identifier.discord:` principals.
- **Differences from the RPStack documented order** (`CLAUDE.md` "server.cfg load order"):
  - No `stop sessionmanager`.
  - No `ensure sessionmanager-rdr3`.
  - No `ensure rconlog`.
  - The server boots, so VORP's recipe evidently does not need them **[inferred]**.

### 2.2 Resource versions and dependencies

Versions come from each `fxmanifest.lua` `version` field. The "Uses" column comes from cross-resource `exports.*` usage found in source; only three manifests declare `dependencies`.

| Resource | Ver. | Uses (exports) | DB |
| --- | --- | --- | --- |
| vorp_core | 3.3 | vorp_inventory, vorp_menu | oxmysql |
| vorp_lib | 0.4 | vorp_core | – |
| vorp_inventory | 1.0 | vorp_core, vorp_lib, vorp_animations | oxmysql |
| vorp_character | 2.1 | vorp_core, vorp_menu; `@vorp_core/client/dataview.lua` | oxmysql |
| vorp_admin | 2.6 | vorp_core, vorp_inventory, vorp_menu | oxmysql |
| vorp_banking | 1.9 | vorp_core, vorp_inventory, vorp_menu | oxmysql |
| vorp_stores | 2.4 | vorp_core, vorp_inventory, vorp_menu | – |
| vorp_police | 0.6 | vorp_core, vorp_inventory, vorp_inputs, vorp_menu, vorp_lib (`Import`) | – |
| vorp_billing 0.2, vorp_medic 0.3, vorp_housing 0.2, vorp_doorlocks 0.5, vorp_stables 1.3, vorp_weaponsv2 2.3, vorp_crafting 1.8, vorp_hunting 1.0.5, vorp_paycheck 0.2, vorp_lootnpcs 1.4, vorp_metabolism 1.2, vorp_barbershop 1.0, vorp_fishing 1.2, vorp_herbs 1.2, vorp_mining 1.2, vorp_lumberjack 1.2, vorp_crawfish 2.0, vorp_walkanim 1.3, vorp_wildhorse 1.2, vorp_mailbox 1.0, vorp_outlaws 1.0, vorp_animations 1.0, vorp_inputs 1.2, vorp_menu 1.3, vorp_progressbar 1.2.1, vorp_zonenotify 1.1, vorp_utils 1.1.1, vorp_postman (no version), vorp_imapviewtool (1.1, not ensured) | | mostly vorp_core + vorp_inventory | some |
| oxmysql 2.12.3, pma-voice 7.0.1, PolyZone 2.6.2, loadingscreen 1.2, lockpick 1.0 | | | |

Notes:

- Declared manifest `dependencies`: only `vorp_crafting` (progressbar), `vorp_fishing` (core, inventory), `vorp_lumberjack` / `vorp_mining` (syn_minigame). Everything else relies on `server.cfg` order.
- `vorp_mailbox` writes through `exports.ghmattimysql` (`vorp_mailbox/server/server.lua:47`, `:187`, `:190`), and ghmattimysql is not installed. The mailbox is likely broken **[inferred]**.
- vorp_core checks its own name, requires `steam_webApiKey` and OneSync (`vorp_core/server/init.lua:21-34`), and polls GitHub for versions (`:100-183`).

---

## 3. VORP public API (focus resources)

### 3.1 vorp_core

**Server exports**

| Export | Signature / returns | Citation |
| --- | --- | --- |
| `GetCore` | `() → CoreFunctions` | `vorp_core/server/apicontroller.lua:285-287` |
| `vorpAPI` | deprecated wrapper around local events | `vorp_core/server/old_api.lua:2-62` |
| `ServerRpcCall` | `() → ServerRPC` | `vorp_core/server/class/callbacks.lua:136-138` |

**`CoreFunctions` members**

| Member | Behavior | Citation |
| --- | --- | --- |
| `getUser(source)` | → user table or `nil`, resolved by **Steam** identifier | `apicontroller.lua:45-52` |
| `getUserByCharId(charid)` | online only; linear scan | `:54-62` |
| `getUsers()` | → **raw internal `_users` table** | `:41-43` |
| `maxCharacters(source)` | max characters for the player | `:37-39` |
| `Notify*` (17 variants) | each a `TriggerClientEvent` | `:64-130` |
| `dbUpdateAddTables(tbl)`, `dbUpdateAddUpdates(updt)` | DB auto-updater hooks | `:132-138` |
| `AddWebhook(title, webhook, description, color, name, logo, footerlogo, avatar)` | Discord webhook | `:140-142` |
| `Callback.Register(name, fn(source, cb, ...))`, `Callback.TriggerAsync(name, source, cb, ...)`, `Callback.TriggerAwait(name, source, ...)` | RPC callbacks | `:144-167` |
| `Whitelist.getEntry / whitelistUser / unWhitelistUser` | whitelist management | `:169-198` |
| `Player.Heal / Revive / Respawn(source, param)` | fire `vorp_core:Server:OnPlayer*` and the client equivalents | `:200-224` |
| `RegisterJobs(data, resourcename)`, `GetRegisteredJobs(job?)` | job registry | `:226-282` |

**User object** (`getUser(src)`; built in `vorp_core/server/class/user.lua:120-174`)

- Fields: `source`, `getGroup`, `getCharperm`, `maxJobsAllowed`.
- Methods: `getIdentifier()`, `setGroup(g)`, `setCharperm(n)`, `setMaxJobsAllowed(n)`, `getPlayerwarnings()`, `setPlayerWarnings(n)`, `getNumOfCharacters()`, `addCharacter(data)`, `removeCharacter(charid)`, `setUsedCharacter(charid)`.
- `getUsedCharacter` and `getUserCharacters` are **evaluated when `GetUser()` is called** (`user.lua:125-126`). Hold a fresh reference; don't cache it.

**Character object** (`user.getUsedCharacter`; built in `vorp_core/server/class/character.lua:531-694`)

- A snapshot of fields: `identifier`, `charIdentifier`, `group`, `job`, `jobLabel`, `jobGrade`, `money`, `gold`, `rol`, `xp`, `firstname`, `lastname`, `inventory`, `status`, `coords`, `isdead`, `skin`, `comps`, `compTints`, `age`, `gender`, `charDescription`, `nickname`, `invCapacity`, `skills`, `multiJobs`.
- Plus setter closures that mutate the live object:
  - `addCurrency(currency, qty)`, `removeCurrency(currency, qty)`; currency `0=money`, `1=gold`, `2=rol` (`character.lua:366-393`).
  - `setMoney`, `setGold`, `setRol`, `setXp`, `addXp`, `removeXp`.
  - `setJob(job, flag)`, `setJobGrade`, `setJobLabel`, `setGroup(group, flag)`, `setMultiJob`, `removeMultiJob`.
  - `updateSkin`, `updateComps`, `updateCompTints`, `setSkills`, `updateInvCapacity`, `setStatus`, name/age/gender/description/nickname setters.

**Client→server net events** (all in `vorp_core/server/`)

| Event | Args | Citation |
| --- | --- | --- |
| `vorp:playerSpawn` | – | `loadusers.lua:181` |
| `vorp:SaveHealth` | `healthOuter, healthInner` | `loadusers.lua:210` |
| `vorp:SaveStamina` | `staminaOuter, staminaInner` | `loadusers.lua:228` |
| `vorp:HealthCached` | 4 numbers | `loadusers.lua:243` |
| `vorp:GetValues` | – | `loadusers.lua:261` |
| `vorp:ImDead` | `isDead` | `loadcharacter.lua:24` |
| `vorp:SaveDate` | – | `loadcharacter.lua:37` |
| `vorp_core:PlayerRespawnInternal` | `param` | `loadcharacter.lua:46` |
| `vorp_core:Server:OnPlayerDeath` | `killerServerId` | `loadcharacter.lua:52` |
| `vorp_core:instanceplayers` | `setRoom` | `instance.lua:5` |
| `vorp:SwitchMultiJobMenu` | `job` | `commands.lua:538` |
| `vorp:chatSuggestion` | – | `commands.lua:601` |
| `vorp:TriggerServerCallback` | `name, uniqueId, isSync, ...` | `class/callbacks.lua:32` |
| `vorp:ServerCallback` | `uniqueId, isSync, name, ...` | `class/callbacks.lua:132` |
| `vorp:addNewCallBack` | `name, callback` | `class/callbacks.lua:141` |

**Server-local events** (safe: not net-registered anywhere; checked by grep)

- Fired by core:
  - `vorp:SelectedCharacter(source, characterTable)` (`user.lua:32`).
  - `vorp:playerGroupChange(source, new, old)` (`character.lua:100`).
  - `vorp:playerJobChange(source, new, old)` (`character.lua:112`).
  - `vorp:playerJobGradeChange(source, new, old)` (`character.lua:140`).
  - `vorp_core:Server:OnPlayerLevelUp` (`character.lua:297`).
  - `vorp_core:Server:OnPlayerHeal`, `OnPlayerRevive`, `OnPlayerRespawn` (`apicontroller.lua:205-221`).
- Consumed by core:
  - `vorp:addMoney`, `vorp:removeMoney`, `vorp:setJob`, `vorp:setGroup`, `vorp:addXp`, `vorp:removeXp`, `vorp:getCharacter` (`old_api.lua:84-155`).
  - `vorpbans:addtodb` (`bans.lua:3`), `vorpwarns:addtodb` (`bans.lua:22`), `vorp_core:addWebhook` (`logs.lua:4`).

**Commands:** ~25 admin commands are registered from `vorp_core/config/commands.lua` by `vorp_core/server/commands.lua:70-108`. Permission is ACE **or** the VORP group (`commands.lua:78-82`).

### 3.2 vorp_character

- **Server export:** `OpenOutfitsMenu(source)` (`vorp_character/server/server.lua:369`).
- **Client exports:** `GetPlayerComponent(category)`, `GetAllPlayerComponents()` (`vorp_character/client/functions.lua:577`, `:595`).

**Net events** (all `server/server.lua`)

| Event | Args | Line |
| --- | --- | --- |
| `vorpcharacter:saveCharacter` | `data` | 122 |
| `vorpcharacter:deleteCharacter` | `selectedChar` | 133 |
| `vorp_CharSelectedCharacter` | `charid` | 150 |
| `vorpcharacter:setPlayerCompChange` | `skinValues, compsValues` | 164 |
| `vorp_character:server:GoToSelectionMenu` | – | 189 (net only when `Config.DevMode`, which is `false` in `config.lua:6`) |

**Callbacks** (all `server/server.lua`)

| Callback | Line |
| --- | --- |
| `vorp_characters:getMaxCharacters` | 216 |
| `vorp_character:callback:PayToShop` (`{amount, skin, comps, compTints, Result}`) | 226 |
| `…:CanPayForSecondChance` | 284 |
| `…:PayForSecondChance` | 298 |
| `…:GetOutfits` | 327 |
| `…:SetOutfit` | 335 |
| `…:DeleteOutfit` | 357 |

**Server-local events**

- Consumed: `vorp_CreateNewCharacter(source)` (`:108`), `vorp_character:server:SpawnUniqueCharacter(source)` (`:180`).
- Fired: `vorp_NewCharacter(source)`, 3 s after creation (`:128-130`).

### 3.3 vorp_inventory

**Server exports:** about 75, listed at `vorp_inventory/server/services/inventoryApiService.lua:2009-2085`. Each returns its result synchronously **and** calls an optional `cb` (`respond`, `:34-38`). Key signatures:

| Export | Signature | Line |
| --- | --- | --- |
| `addItem` | `(source, name, amount, metadata, cb, allow, degradation, percentage)` | `:286` |
| `subItem` | `(source, name, amount, metadata, cb, allow, percentage)` | `:490` |
| `subItemById` | `(source, id, cb, allow, amount)` | `:456` |
| `getItemCount` | `(source, cb, itemName, metadata, percentage)` | `:198` |
| `canCarryItem` | `(source, itemName, amount, cb)` | `:122` |
| `canCarryItems` | `(source, _, cb)` | `:103` |
| `getUserInventoryItems` | `(source, cb)` | `:1427` |
| `registerUsableItem` | `(name, cb(data), resourceName)` | `:177` |
| `createWeapon` | `(source, wepname, ammos, _, comps, cb, wepId, serial, label, desc, setUsed)` | `:1187` |
| `deleteWeapon` | `(source, weaponId, cb)` | `:1172` |
| `subWeapon` | `(source, weaponId, cb)` | `:1460` |
| `registerInventory` | `(data)` | `:1510` |
| `openInventory` | `(data, cb)` | `:1941` |
| `removeInventory` | `(id)` | `:1554` |
| `AddPermissionMoveToCustom` | `(id, job, grade)` | `:1515` |
| `AddPermissionTakeFromCustom` | `(id, job, grade)` | `:1522` |
| `addItemsToCustomInventory` | `(id, items, charid, cb, identifier)` | `:1637` |
| `removeItemFromCustomInventory` | `(id, item_name, amount, item_crafted_id, cb)` | `:1757` |
| `addAllowedContextMenuEvent` | `(event, resourcename)` | `vorp_inventory/server/server.lua:153` |
| `vorp_inventoryApi` | deprecated | `vorp_inventory/server/vorpInventoryApi.lua:2` |

**Net events** (`vorp_inventory/server/controllers/inventoryController.lua:2-36`)

- Give: `serverGiveItem(itemId, amount, target)`, `serverGiveWeapon(weaponId, target)`, `giveMoneyToPlayer(target, amount)`, `giveGoldToPlayer(target, amount)`, `servergiveammo(ammotype, amount, target, maxcount)`.
- Pickup: `onPickup(data)`, `onPickupMoney / Gold / Roll(data)`.
- Use and move: `useItem(data)`, `MoveToCustom(json)`, `TakeFromCustom(json)`, `MoveToPlayer(json)`, `TakeFromPlayer(json)`.
- Weapons and ammo: `setUsedWeapon`, `updateammo`, `AddBulletFromWeapon`, `updateweapons`, `weaponReloaded`, `setWeaponAmmoType`, `saveWeaponStatus`, `dropThrowableWeapon`, `pickUpThrowableWeapon`, `removeLasso`, `vorpCore:LoadAllAmmo`.
- Other: `getItemsTable`, `getInventory`, `vorp:PlayerForceRespawn`.
- Also in `server/server.lua`: `syn:stopscene` (`:9`), `vorpinventory:netduplog` (`:15`), `vorp_inventory:Server:SaddleOpen(netId)` (`:88`), `…:CloseCustomInventory` (`:112`), `vorpinventory:validateContextMenuEvent(data)` (`:133`).

**Callbacks:**

- `vorp_inventory:callback:` `GetAmmoInfo`, `HandCrafting`, `DropRoll`, `DropMoney`, `DropGold`, `DropWeapon`, `DropItem`, `AddWeaponComponent`, `RemoveWeaponComponent`, `cleanWeapon` (`inventoryController.lua:40-49`).
- `vorpinventory:get_slots` (`server.lua:71`).

**Server-local events fired** (hook points):

- `vorp_inventory:Server:OnItemRemoved` (`inventoryService.lua:594`, `:1375`).
- `…:OnItemCreated` (`:639`).
- `…:OnItemUse` (`:1347`).
- `…:OnItemMovedToCustomInventory` (`:2532`).

### 3.4 vorp_banking

All in `vorp_banking/server/server.lua`:

| Kind | Name | Args | Line |
| --- | --- | --- | --- |
| Callback | `vorp_bank:getinfo` | `bankName` | 34 |
| Net event | `vorp_bank:UpgradeSafeBox` | `slotsToBuy, currentspace, bankName` | 87 |
| Net event | `vorp_bank:transfer` | `amount, fromBank, toBank` | 146 |
| Net event | `vorp_bank:depositcash` | `amount, bankName` | 192 |
| Net event | `vorp_bank:depositgold` | `amount, bankName` | 217 |
| Net event | `vorp_bank:withcash` | `amount, bankName` | 239 |
| Net event | `vorp_bank:withgold` | `amount, bankName` | 268 |
| Net event | `vorp_banking:server:OpenBankInventory` | `bankName` | 295 |

No exports.

### 3.5 vorp_admin

All in `vorp_admin/server/server.lua`:

- **Net events:** 46 `vorp_admin:*`, lines 95–978, plus `vorp:teleportWayPoint` (`:792`). Every action handler calls `AllowedToExecuteAction(source, action)` (`:77-90`), which maps the **VORP users.group** (`Config.UseCharactersAdmin = false`, `vorp_admin/config.lua:5`) to `Config.AllowedActions` (`config.lua:264-273`).
- **Callbacks:** `vorp_admin:Callback:getplayersinfo` (`:48`, **no permission check**), `vorp_admin:CanOpenStaffMenu` (`:817`).
- **Local event:** `vorp_admin:logs`.

### 3.6 vorp_lib

- **Import system:** `vorp_lib/import.lua`. Client modules include blips, prompts, points, polyzones, entities, commands, streaming, and inputs. The server module is `commands` (`vorp_lib/server/modules/commands.lua`).
- **Server exports:** `SetDefaultDensityMultipliers`, `SetTemporaryDensityMultipliers`, `RemoveTemporayDensityMultipliers` (`vorp_lib/server/main/main.lua:49-60`).
- **Net event:** `vorp_library:Server:DeleteEntity(netid)` (`main.lua:2`).

### 3.7 vorp_stores

All in `vorp_stores/server/server.lua`:

- **Net events:** `vorp_stores:Client:sellItems(dataItems, storeId)` (`:206`), `vorp_stores:Client:buyItems(dataItems, storeId)` (`:223`), `vorp_stores:GetRefreshedPrices` (`:386`).
- **Callbacks:** `getShopStock` (`:259`), `ShopStock` (`:328`), `canOpenStore` (`:336`), `CloseStore` (`:347`).

### 3.8 vorp_police

All in `vorp_police/server/main.lua`:

- **Exports:** `isOnDuty(source)`, `getPoliceFromCall(source)` (`:815-816`).
- **Net events:** `vorp_police:Server:OpenStorage(key)` (`:75`), `…:server:hirePlayer(id, data)` (`:120`), `…:server:firePlayer(id)` (`:183`), `…:Server:dragPlayer(target)` (`:236`), `vorp_core:Server:OnPlayerDeath` (`:805`).
- **Callback:** `vorp_police:server:checkDuty` (toggles duty, `:326`).
- **Commands:** police menu, alert / cancel / finish, jail / unjail / changeJailTime / checkJailTime (`:64-755`).
- **Jobs:** registered through `Core.RegisterJobs` (`:251-262`).

---

## 4. Data model

Schema comes from the live DB dump. There are no `rpstack_*` tables in this DB.

| Table | Key columns | Written by (verified) |
| --- | --- | --- |
| `users` | `identifier` PK (Steam hex), `group`, `warnings`, `banned`, `banneduntil`, `char` (max chars), `max_jobs` | vorp_core: `loadusers.lua:173` (insert), `class/user.lua:87,95,104,114`, `bans.lua:18`; cleanup `loadusers.lua:286` |
| `characters` | `charidentifier` AUTO_INCREMENT; `identifier` FK→users (cascade); `group`, `job`, `jobgrade`, `joblabel`, `multijobs`; **`money/gold/rol double(11,2)`**; `inventory`, `ammo`, `skinPlayer`, `compPlayer`, `compTints`, `coords`, `isdead`, `skills`, `meta` (unused by core), `discordid`, `LastLogin` | vorp_core: `class/character.lua:329,338,347,450,490,494,498`, `loadusers.lua:40`, `whitelist.lua:79`, `loadcharacter.lua:42`. vorp_inventory: `ammo` (`inventoryService.lua:751`, `:1672`, `:1852`). vorp_walkanim (1 update) |
| `whitelist` | `id`, `identifier` unique, `status`, `firstconnection`, `discordid` | vorp_core `server/class/whitelisting.lua:37-53` |
| `items` (997 rows), `item_group`, `item_rarity` | `item` PK name, `limit`, `usable`, `can_remove`, `metadata`, `degradation`, `weight` | seeded by the recipe; read by vorp_inventory `itemsDatabase.lua` |
| `items_crafted` | `id`, `character_id`, `item_id`, `metadata`, `durability` | vorp_inventory `services/DbService.lua:27,34,50,60` |
| `character_inventories` | `character_id`, `inventory_type`, `item_crafted_id`, `amount`, `degradation` (no PK) | vorp_inventory `DbService.lua:20,46,68` |
| `loadout` | `id`, `identifier`, `charidentifier`, `name`, `ammo`, `comps`, `curr_inv`, `dropped`, `serial_number` | vorp_inventory (`inventoryApiService.lua:1180`, `inventoryService.lua:1024`, `:2484`) |
| `bank_users` | `id`, `name` (bank), `identifier`, `charidentifier`, **`money/gold double(22,2)`**, `invspace` | vorp_banking `server/server.lua:68,114,167,170,208,229,255,283` |
| `outfits` | `id`, `identifier`, `charidentifier` FK→characters | vorp_character `server/server.lua:264,363` |
| `stables`, `horse_complements`, `wagons` | char-keyed | vorp_stables `Server/main.lua:50,116,179`; vorp_admin `server.lua:383,407,414` |
| `mailbox_mails` | sender/receiver ids | vorp_mailbox via ghmattimysql (see §2.2) |
| `housing`, `rooms`, `herbalists` | char-keyed | writers not located by grep **[unverified]** |

Observations:

- **No ledger or transaction table exists anywhere.** The only audit mechanism is Discord webhooks, and every webhook URL checked is empty: `vorp_core/config/logs.lua:7-11`, `vorp_inventory/config/config_server.lua:123,161`.
- Money is a floating-point `double` in both `characters` and `bank_users`.
- **Auto-updater** (`vorp_core/server/services/dbupdater/dbupdater.lua`):
  - It holds only one update (`users.char` default, `:22-36`).
  - It is count-based via `status.json`, not name-based (`:111-132`). Current `status.json` is `{"updatecount":1,"tablecount":0}`.
  - Other resources can add entries through `dbUpdateAddTables` / `dbUpdateAddUpdates`.
- `character_inventories.character_id` holds `charidentifier` (int). `USERS_ITEMS.default` is keyed by the **Steam identifier** in memory (`inventoryService.lua:545`), so only one character per account can be live.

---

## 5. Core systems

### 5.1 Character lifecycle

1. **Connecting** (`vorp_core/server/whitelist.lua:42-81`).
   - Defers the connection.
   - **Requires a Steam identifier**, otherwise kicks (`:46-53`).
   - Optional whitelist (`Config.Whitelist = false`, `config.lua:57`).
   - Ban check against `users.banned` (`:18-40`).
2. **Joining** (`loadusers.lua:150-176`).
   - Rejects a duplicate license (`:160-163`).
   - Loads or creates the `users` row. **The first user ever inserted gets group `admin`** (`:170-171`).
   - Builds `User` keyed by Steam id and loads characters asynchronously (`user.lua:192-238`).
3. **Client spawn** (`vorp_core/client/spawnplayer.lua:51-60`).
   - The client sends `vorp:playerSpawn`.
   - The server puts the player in a fresh routing bucket (`loadusers.lua:194-195`).
   - With zero characters: `vorp_CreateNewCharacter` → client creator (`vorp_character/server/server.lua:108-110`).
   - Otherwise the selection menu, because `users.char` (default 5) > 1 (`loadusers.lua:203-204`).
4. **Create.**
   - The client sends `vorpcharacter:saveCharacter(PLAYER_DATA)` (`vorp_character/client/menu.lua:526`).
   - `User.addCharacter` → INSERT → `UsedCharacterId(id)` (`user.lua:240-283`).
   - Then `vorp:SelectedCharacter` fires (server and client, `user.lua:31-32`) and state bags are set (`:33-49`).
   - The client is teleported to a random `Config.SpawnCoords` entry (`vorp_character/server/server.lua:126-127`).
   - After 3 s, `vorp_NewCharacter` fires and the starter kit is granted (`inventoryService.lua:2074-2085`).
5. **Select.**
   - The client sends `vorp_CharSelectedCharacter(charid)`.
   - A once-per-source guard applies (`vorp_character/server/server.lua:149-160`).
   - `setUsedCharacter` accepts only ids in the player's own character map (`user.lua:300-307`).
   - The client teleports to the saved coords (`client/client.lua:350-359`) and leaves the bucket via `vorp_core:instanceplayers 0` (`spawnplayer.lua:192`).
6. **Active character, server-side.**
   - `exports.vorp_core:GetCore().getUser(src).getUsedCharacter.charIdentifier` (`apicontroller.lua:45-52`; `user.lua:125`).
   - Reverse lookup: `getUserByCharId(charid)` (online only, `apicontroller.lua:54-62`).
   - Do **not** trust `Player(src).state.Character.CharId` (`user.lua:34-49`). It is a replicated player state bag, and clients can write their own player state **[verified]** (A3, H9).
7. **Logout** happens only by disconnecting.
   - `playerDropped` → `savePlayer` (coords and full row) → state bags cleared (`loadusers.lua:18-42`, `:125-135`).
   - `_users[identifier]` is removed **6 s later** (`:58-62`).
   - There is no in-session character switch (`loadusers.lua:137-148` commented out; `vorp_character/server/server.lua:148`).
   - There is no "character unloaded" event; `playerDropped` is the only signal.

### 5.2 Money

- **Currencies:** `0` dollars, `1` gold, `2` "rol" (tokens) (`character.lua:366-393`).
  - New characters start with `initMoney = 200.0` and `initGold = 0.0` (`config.lua:39-43`).
  - Bank balances live per bank per character in `bank_users`.
- **Mutation:** `addCurrency` / `removeCurrency` change in-memory fields with **no validation** — the code carries its own comment, `--add check for security`. Negative quantities are accepted and balances may go negative (`character.lua:366-393`).
- **Persistence:**
  - In memory, flushed by `SaveCharacterInDb` (`character.lua:497-528`) every `savePlayersTimer = 10` minutes (`config.lua:71`; loop in `saveusers.lua:1-12`) and on drop.
  - Inventory items are **write-through** (`DbService.lua:58-77`).
  - So a crash between a purchase and the next save persists the item but loses the money deduction **[inferred]**.
- **Atomicity:**
  - None across currencies, characters, or banks.
  - Bank operations read, then write the absolute value (`vorp_banking/server/server.lua:203-208`, `:249-255`, `:156-170`).
  - The only concurrency guards are a per-user processing flag in inventory (`SV_UTILS.PROCESS`, `services/UtiliyService.lua:188+`) and an ad hoc `lastMoney` check on cash withdrawal (`vorp_banking/server/server.lua:237-256`).
- **Ledger:** none (§4).
- **Bug:** `removeXp` assigns to `self.Xp`, overwriting the getter function (`character.lua:403`).

### 5.3 Jobs, groups, permissions

- **Three overlapping systems:**
  1. **ACE** from `server.cfg:100-109` and `vorp_admin/vorp_perms.cfg:16-33`. The cfg grants `vorpcore.*` aces to `group.owner`; the owner's principals in `server.cfg` are `group.admin`, so they don't receive those aces.
  2. **VORP account group** `users.group`. Commands accept ACE **or** a `groupAllowed` match (`commands.lua:78-82`). vorp_admin uses `users.group` exclusively (`vorp_admin/server/server.lua:77-90`).
  3. **Character fields:** `group`, `job`, `jobgrade`, `multijobs`, switchable through `vorp:SwitchMultiJobMenu` (`commands.lua:538-576`).
- **Job registry:**
  - `Config.REGISTERED_JOBS` / `RegisterJobs` (`apicontroller.lua:226-274`; `config/jobs.lua`).
  - Admin job validation is commented out (`commands.lua:192-194`).
  - `RegisterJobs` never registers `groups`, because `type(v.groups) ~= "array"` is always true in Lua (`apicontroller.lua:262`).
- **Admin status in practice:** `users.group == "admin"`, which the first joiner receives automatically (`loadusers.lua:171`). Any group with `set_group` (including `moderator`, `vorp_admin/config.lua:203`) can assign `admin`.

### 5.4 Inventory

- **Definitions:** DB `items` (997 rows), cached server-side as `SERVER_ITEMS` (`itemsDatabase.lua`).
- **Instances:** `items_crafted` + `character_inventories`, held in memory as `USERS_ITEMS[invId][identifier]`.
- **Weapons:** in `loadout`, held in **one global map `USERS_WEAPONS.default[weaponId]`** that is not partitioned by owner. On drop, only **one** of the owner's weapons is evicted (`vorp_inventory/server/server.lua:62-66`).
- **Authority:** the server holds the state and clients reference ids. Validation of amounts, ownership, and names is incomplete (§6).
- **Custom inventories:** gated by "opened through the server" plus job/charid permissions (`inventoryService.lua:2374-2396`, `:2415-2436`).

---

## 6. Security audit against the RPStack trust boundary

**Method:** every client-reachable server entry point (net event or `Core.Callback.Register`) in the focus resources that changes money, items, jobs, or character state was read. "Validates" means it checks: source identity / ownership, sign and range of amounts, distance, rate.

**Systemic findings:**

- No handler in the focus resources rate-limits (V2).
- `SV_UTILS.PROCESS` is a per-user mutex, not a rate limit.
- No handler checks that amounts are positive integers. Combined with sign-agnostic `add/removeCurrency` and `quitCount` (`vorp_inventory/shared/models/ItemClass.lua:265-271`), every "remove N" with negative N becomes "add |N|".

### Critical (one ordinary client creates money or items)

| ID | Entry point | Defect | Evidence |
| --- | --- | --- | --- |
| C1 | `vorp_stores:Client:buyItems` / `sellItems` | Price, currency, quantity, item name, and weapon flag all come from the client payload. Store config is never consulted; no proximity or store check. Buys any DB item or weapon for any price (0 or negative); sells for any price. | `vorp_stores/server/server.lua:78, 143-171, 206-255` |
| C2 | Callbacks `DropMoney` / `DropGold` / `DropRoll` | `data.amount > balance` is the only check. A negative amount passes and `removeCurrency(-N)` adds N. | `inventoryService.lua:1163-1168, 1207-1212, 1252-1257`; registered `inventoryController.lua:42-44` |
| C3 | Callback `DropItem` | A negative `data.amount` passes `> count`, and `ITEM.REMOVE` → `quitCount(-N)` increases the stack, persisted to DB. | `inventoryService.lua:1114-1119, 1368-1380` |
| C4 | `vorp_inventory:MoveToCustom` | Adds `data.item.name` with `data.item.metadata` (client-supplied) to the storage, then removes `item.id`. `CanProceed` checks only that the id exists with enough count, never that the name matches. Any owned item becomes any item, with arbitrary metadata. Needs access to any custom inventory (bank safebox, saddlebag). | `inventoryService.lua:2439-2454, 2508-2531`; `CanProceed` `:151-181`; `ITEM.ADD` uses `name` `:1386-1412` |
| C5 | vorp_banking events | **Deposit:** negative `amount` → `playerCash >= amount` → cash +N, bank −N, and bank goes negative unbounded. **Transfer:** negative → +N/−0.9N. **UpgradeSafeBox:** client supplies `currentspace` (free slots) and negative `slotsToBuy` (money added). `fromBank` is unchecked; there are no positive-amount checks anywhere. | `vorp_banking/server/server.lua:97-117, 163-170, 202-208, 227-229` |
| C6 | Callback `vorp_character:callback:PayToShop` | `amount` comes from the client, so a negative amount means `removeCurrency(0, -N)` adds money. Skin, comps, and outfits are applied regardless of price. | `vorp_character/server/server.lua:233-246` |

### High

| ID | Entry point | Defect | Evidence |
| --- | --- | --- | --- |
| H1 | `vorp:addNewCallBack` (net) | Any client can (re)register any server callback name, replacing the real handler for everyone. That is a server-wide DoS of every callback flow (drops, stores, character, banking info, police duty). Whether a client-supplied function reference is executable server-side is **[inferred: no]**. | `vorp_core/server/class/callbacks.lua:141, 45-50` |
| H2 | `vorp:ServerCallback` (net) | Resolves any pending server→client callback by `uniqueId`. The responder is never checked against the asked client. IDs are `name..counter`, so they are predictable. The "target accepts the give" prompt (`TriggerAwait("vorp_inventory:callback:wantToGiveItems", target, …)`) can be answered by the giver **[inferred chain]**. | `callbacks.lua:91, 108, 118-132`; `inventoryService.lua:268` |
| H3 | `giveMoneyToPlayer` / `giveGoldToPlayer` / `serverGiveItem` | No positive-amount or distance check. A negative amount moves value from target to giver. With an alt or a forged consent (H2), the target's item stack can go negative while the giver gains. | `inventoryService.lua:275-336, 338-397, 528-674`; `ItemClass.lua:257-263` (`addCount` has no floor) |
| H4 | Weapon ownership | `serverGiveWeapon`, `DropWeapon`, `MoveToCustom` (weapon branch), `removeLasso`, `dropThrowableWeapon`, `weaponReloaded`, `AddBulletFromWeapon`, and `setWeaponAmmoType` check only that `USERS_WEAPONS.default[weaponId]` exists, never the owner. Weapon ids are sequential and stay resident after the owner leaves. Any loaded weapon can be stolen. | `inventoryService.lua:408, 1041, 152-156, 2187-2206, 2252-2257, 1595-1668`; `inventoryApiService.lua:1172-1179`; `server/server.lua:62-66` |
| H5 | `vorpcharacter:saveCharacter` | No max-character check and no server validation of name, age, or appearance (client-only checks at `client/menu.lua:430-461`). Callable repeatedly and mid-session, so each call creates a character with `initMoney 200`. It switches the active character (bypassing the selection guard) and re-fires `vorp_NewCharacter`, which re-grants the starter kit. Violates V9 "exactly once". | `vorp_character/server/server.lua:122-131`; `user.lua:240-283`; `inventoryService.lua:2074-2085`; `config.lua:41` |
| H6 | `vorp_police:server:hirePlayer` | `data.job`, `data.grade`, and `data.label` come from the client, and the target may be the caller. Any officer with `canHire` can set anyone, including themself, to any job at any grade. | `vorp_police/server/main.lua:140-161` |
| H7 | `vorp_bank:withgold`, `depositcash`, `transfer` | Read-then-absolute-write with no lock. Concurrent events double-spend (gold withdraw has no `lastMoney` guard) or lose updates **[inferred race]**. | `vorp_banking/server/server.lua:203-208, 268-291, 156-170` |
| H8 | `vorp_library:Server:DeleteEntity` | Deletes any networked entity by netId: other players' horses and wagons, store NPCs. | `vorp_lib/server/main/main.lua:2-8` |
| H9 | Server reads of player state bags | Clients can write their own `Player(src).state` (A3 **[verified]**), so any server code that reads it for authority or identity is exploitable. `vorp_doorlocks` authorizes doors with per-character permissions by `Player(_source).state.Character.CharId`: a client that sets its own `Character.CharId` to an allowed id opens those doors. `vorp_billing` gates billing on the client-writable `isPoliceDuty` / `isMedicDuty` keys. `IsInSession` gates the periodic save (a client can opt out of autosaves, widening crash-rollback windows), paycheck, and door-permission updates. `PlayerIsInCharacterShops` skips coordinate saving. vorp_core's `SetState` reads the current `Character` table back from the bag and republishes it, so client-injected fields are re-replicated by the server. | `vorp_doorlocks/server/main.lua:61, 204`; `vorp_billing/config.lua:35`; `vorp_core/server/saveusers.lua:5`; `vorp_paycheck/server/main.lua:31`; `vorp_core/server/class/user.lua:311`; `vorp_core/server/class/character.lua:2-8` |

### Medium

| ID | Entry point | Defect | Evidence |
| --- | --- | --- | --- |
| M1 | `vorp_admin:Callback:getplayersinfo` | No permission check. Any client gets every online player's Steam id, money, gold, group, job, and whitelist id. | `vorp_admin/server/server.lua:18-74` |
| M2 | `vorp_admin:setGroup` | No hierarchy: `moderator` (`set_group = true`) can grant `admin`, including to themself. | `server.lua:525-547`; `vorp_admin/config.lua:203` |
| M3 | Pickups | No distance check against the stored `coords`. Uids are broadcast to all clients, so items can be picked up remotely. The item is added before the pickup is claimed, so concurrent pickups may duplicate **[inferred]**. | `inventoryService.lua:768-893` (`:798-800`), `895-1003`; broadcast `:203` |
| M4 | `vorpcharacter:setPlayerCompChange`, callback `SetOutfit` | Free appearance changes (bypassing paid shops) and unbounded JSON written to DB on every call. | `vorp_character/server/server.lua:164-177, 335-355` |
| M5 | `vorpcharacter:deleteCharacter` | Deletes the **active** character mid-session. Server-side confirmation is absent. The webhook string concatenates client fields, so nil values crash the handler. | `server.lua:133-146` |
| M6 | Police `firePlayer`, `dragPlayer`, cuff item | Fire has no rank or proximity check. Drag has no distance or duty check. The cuff target is chosen by the client callback. | `vorp_police/server/main.lua:183-212, 236-245, 287-298`; client `client/main.lua:456-466` |
| M7 | `vorp_core:instanceplayers` | The client picks any routing bucket. | `vorp_core/server/instance.lua:5-54` |
| M8 | `vorp:ImDead`, `vorp:playerSpawn` | Death flag is client-controlled (gates respawn penalties and police alerts). `playerSpawn` is re-triggerable: new bucket, selection or creator re-opened. | `loadcharacter.lua:24-34`; `loadusers.lua:181-207` |
| M9 | `weaponReloaded` | A negative `amount` increases belt ammo without the belt cap. | `inventoryService.lua:1595-1611` |
| M10 | Store lock callbacks | Any client can lock or unlock any store (`canOpenStore` / `CloseStore`). | `vorp_stores/server/server.lua:336-353` |
| M11 | Non-focus resources, same pattern | Client-priced payment in `vorp_barbershop:payforservice` (`vorp_barbershop/server/server.lua:19-29`) and `vorp_weapons:checkmoney` (`vorp_weaponsv2/server/server.lua:24-35`). `vorp_billing:server:SendBill` checks only the max amount, not the sign (`vorp_billing/server/main.lua:78-94`). | as cited |

### Low

- `vorp_core:Server:OnPlayerDeath`: spoofed killer, affects webhook text only (`loadcharacter.lua:52-79`).
- `vorp:SaveHealth` / `vorp:SaveStamina` / `vorp:HealthCached`: client-reported vitals (`loadusers.lua:210-259`).
- `vorp:SaveDate`: nil-index crash if no character (`loadcharacter.lua:37-43`).
- `charSelected[source]` is never cleared, so a reused source id cannot select **[inferred]** (`vorp_character/server/server.lua:149-160`).
- Police jail persistence multiplies an absolute timestamp by 60 on rejoin (`vorp_police/server/main.lua:704-706`).

### Operational

- **First joiner becomes admin** (`loadusers.lua:170-171`). If the DB is reset while the server is public, a stranger can be first.
- **Secrets** sit in `server.cfg`: license key, Steam API key, DB password (weak) (`server.cfg:14,18,19`).
- **Webhooks:** all are empty, so there is no audit trail at all.

---

## 7. Fit/gap mapping

| RPStack module | VORP equivalent | Decision | Reasons |
| --- | --- | --- | --- |
| rpstack-core (logger, errors, services) | none (VORP has `vorp_lib/shared/logger.lua`, client-oriented) | **Keep** | No overlap. Needed by every RPStack module. |
| rpstack-persistence (oxmysql wrapper, migrations) | oxmysql + vorp_core dbupdater (count-based, `dbupdater.lua:111-132`) | **Keep** | Named, idempotent migrations are stronger than VORP's counter. `rpstack_*` tables coexist in DB `rpstack` with no name clash (VORP tables are unprefixed). |
| rpstack-identity (accounts, sessions, multi-character) | vorp_core `users`/`characters` + `User`/`Character` classes + vorp_character | **Retire** (already decided) → replace with **bridge exports** | VORP owns the connect, select, and spawn flow. Gap vs V6: VORP keys accounts by **Steam hex string** (`users.identifier`) and requires Steam (`whitelist.lua:46-53`). Use `charidentifier` (int, auto-increment, never reused) as RPStack's cross-module key. Account-level keying needs a decision (Open question 1). |
| rpstack-permissions (roles, policies) | ACE + `users.group` + `characters.job/jobgrade` | **Retire** roles; **adapt** `hasPermission` in the bridge | The VORP group is DB-mutable by any `set_group` holder (M2). For RPStack staff checks use **ACE** (`IsPlayerAceAllowed`, controlled from cfg), not VORP groups. |
| rpstack-economy (balances, ledger, owner accounts, atomic transfer) | `characters.money/gold/rol` (in memory, float, no ledger); `bank_users` | **Retire** character balances (already decided). **Keep the owner-account and ledger concept**, re-hosted (see §8) | VORP has no ledger, no atomic operation, no integer money. Faction treasuries need what economy provided. |
| rpstack-factions | none (VORP has jobs and multijobs, not factions) | **Adapt** (already decided) | No VORP equivalent. Needs host services (§8). Factions has no client surface yet (`resources/rpstack-factions/client/main.lua` is 2 lines), so there's nothing new to secure on the network side. |

---

## 8. Factions adapter spec

`rpstack-factions` uses these host services today:

- `rpstack:identity:getActiveCharacter(src)` (`resources/rpstack-factions/server/main.lua:48-50`).
- `rpstack:identity:getCharacterById(id, cb)` (`server/faction.lua:210-215`).
- Events `rpstack:identity:characterLoaded/Unloaded({characterId})` (`server/main.lua:33-43`).
- `rpstack:economy:createAccountForOwner` (`server/faction.lua:103-110`), `getAccountByOwner` (`server/treasury.lua:50-55`), `transferCash` (`server/treasury.lua:133-144`).
- Persistence exports.

Its own exports take `characterId` / `actorCharId` from the caller (`server/exports.lua:42-130`). The caller is responsible for resolving them from `source`.

Proposal: a single resource **`rpstack-vorp-bridge`**. It is the *only* RPStack code allowed to call VORP APIs, and it exposes the identity and economy export names factions already calls. Factions then changes only its `dependencies` and the target resource name in its export calls.

| Need | VORP API that satisfies it | Gap / RPStack-side guarantee |
| --- | --- | --- |
| **N1 Active character for a source** | `GetCore().getUser(src).getUsedCharacter.charIdentifier` (`apicontroller.lua:45-52`, `user.lua:125`) | Call fresh every time; the user table snapshots `getUsedCharacter` at `GetUser()` time (`user.lua:120-126`). Never read `Player(src).state.Character` (§5.1 step 6). Bridge returns `{ ok, character = { id = charIdentifier, ... } }`. |
| **N2 Character exists / lookup by id** (founder, offline members) | Online: `getUserByCharId(charid)` (`apicontroller.lua:54-62`). Offline: none | Bridge needs a read-only `SELECT charidentifier, firstname, lastname FROM characters WHERE charidentifier = ?`. That is cross-module table access, so document it as the single sanctioned exception in the bridge (read-only, parameterized, never written). |
| **N3 Load/unload lifecycle** | Load: server `vorp:SelectedCharacter(source, char)` (`user.lua:32`). Unload: `playerDropped` only; `_users` lingers 6 s (`loadusers.lua:58-62`) | Bridge keeps `charBySource[src]` from `vorp:SelectedCharacter` and emits `rpstack:identity:characterLoaded/Unloaded({ characterId, source })`. On drop it uses its own map, not VORP lookups (handler order across resources is not guaranteed). Mid-session character change (H5) → on a second `SelectedCharacter` for the same source, emit Unloaded for the old id first. |
| **N4 Treasury owner account (create/read)** | none | RPStack-owned table, e.g. `rpstack_bridge_owner_accounts(owner_type, owner_id, account_type, cash BIGINT UNSIGNED, UNIQUE(owner_type, owner_id, account_type))`, with economy's existing owner-account semantics (`docs/architecture/overview.md` "Economy owner accounts"). Integer dollars only. |
| **N5 Atomic transfer character ↔ treasury** | `removeCurrency/addCurrency` (in memory, no validation, no failure signal, `character.lua:366-393`) | **True atomicity is impossible**: character cash lives in vorp_core memory and is flushed only on a timer (§5.2), while the treasury is in the DB. Implement a **journaled saga** in the bridge (below). |
| **N6 Permissions** | Faction perms are internal to factions. Staff override: ACE | Bridge `hasPermission(src, 'rpstack.factions.admin')` → `IsPlayerAceAllowed`. Do not use `users.group` (M2). |
| **N7 Audit** | none (webhooks only, unconfigured) | Factions already writes `rpstack_faction_audit_log`. The bridge journal (N5) is the money ledger for RPStack-initiated movements. VORP-internal movements (stores, banking, gives) remain unaudited unless hooked via `vorp_inventory:Server:OnItem*` events, and money has no hook. |
| **N8 Client entry points (future)** | – | Any faction UI must use `rpstack:factions:net:*` handlers in RPStack. Resolve `actorCharId` from `source` through N1, rate-limit, and never use VORP callbacks (H1/H2 make that registry untrustworthy). |

### N5: getting a safe transfer without editing VORP

1. **Journal first.** Insert into `rpstack_bridge_cash_journal(id, idem_key UNIQUE, char_id, owner_type, owner_id, direction, amount, state, created_at, updated_at)` with `state='pending'`. The unique key makes retries idempotent, which closes the gap noted in `docs/security/threat-model.md` §3.
2. **Deposit (character → treasury).**
   1. In one uninterrupted tick (no `Wait` or await between the steps): fetch a fresh `getUser(src).getUsedCharacter`, verify `charIdentifier == char_id` and `money >= amount`, then call `removeCurrency(0, amount)`. Set the journal to `char_debited`.
   2. Run `UPDATE … SET cash = cash + ? WHERE …` and set the journal to `committed`.
   3. On DB failure: if the character is still online (`getUserByCharId`), call `addCurrency(0, amount)` and set `compensated`. Otherwise set `needs_reconcile`.
   - Server Lua runs cooperatively on one thread and export calls are synchronous, so step 1 cannot interleave with other handlers **[verified]** (A5).
3. **Withdraw (treasury → character).**
   1. Conditional `UPDATE … SET cash = cash - ? WHERE … AND cash >= ?` and require `affected == 1`.
   2. In one tick: re-verify the character is online and matches, then call `addCurrency(0, amount)` and set `committed`.
   3. If the character went offline, refund the treasury and set `compensated`.
4. **Durability gap.** VORP may lose up to `savePlayersTimer` minutes of character money on a crash (`config.lua:71`, `saveusers.lua:1-12`), which would make a committed deposit a mint. Options, in order of preference:
   - (a) Force a save after each saga through `getUsers()[steamId].SaveUser()`. `getUsers` returns the raw `_users` (`apicontroller.lua:41-43`) and `SaveUser` exists on it (`user.lua:309-322`). Callable across the export boundary and persists to the DB **[verified]** (A2).
   - (b) Lower `savePlayersTimer` (config edit).
   - (c) A startup reconciler for `char_debited` / `needs_reconcile` rows.
5. **Amounts:** positive integers only (`isPositiveInteger` already exists in `resources/rpstack-factions/server/treasury.lua:24-26`). VORP's `double(11,2)` stores them exactly. Gold and rol are out of scope until asked for.
6. **Locking:** the existing per-faction lock in factions (`treasury.lua:5-22`) stays. The bridge adds a per-character lock so two sagas on one character serialize.

---

## 9. First Arrival fit

| First Arrival requirement (`docs/product/first-arrival.md`) | vorp_character today | Status |
| --- | --- | --- |
| Reliable connect, select, create, spawn | Full flow (§5.1). Returning players spawn at saved coords (`client/client.lua:350-359`) | **Covered**, with H5 and M8 caveats |
| Name and age | Inputs exist; validated **client-side only** (`client/menu.lua:430-461`; `Config.MinAge`, `BannedNames` in `config.lua:10-13`) | **Gap:** server validation (V9) |
| Appearance (integrated) | Full creator: body, heritage, hair, face, lifestyle, makeup, clothing, whistle (`client/menu.lua:289-342`, `:1193-1250`); outfits; clothing shops | **Covered** (no custom face engine needed) |
| Origin, reason for arrival, past trade, principle, burden, arrival point | Only nickname and free-text description (`menu.lua:400-418`) | **Missing:** RPStack-owned `rpstack_arrival_story` keyed by `charidentifier` |
| Arrival point | Random from `Config.SpawnCoords` (`vorp_character/server/server.lua:112-120`; `config.lua:32-40`) | **Partial:** RPStack teleports after VORP's spawn |
| Cinematic / in-world arrival, personal lead, story object | Creator photo anim scenes (`menu.lua:494-524`); `Config.UseInitialAnimScene` (`config.lua:22`) | **Missing** |
| Modest starter kit, **exactly once** | `initMoney 200` (`vorp_core/config/config.lua:41`); kit `config_server.lua:18-24`; re-granted on every `vorp_NewCharacter` (H5) | **Gap:** disable VORP's grant (config) and grant from RPStack with a unique `rewarded_at` |
| Recovery from interrupted creation, no duplicates | The row is inserted only at the end (`menu.lua:526`), so interruption leaves nothing (safe restart). But repeated submits create duplicates (H5) | **Partial** |
| Appearance adjustable during a grace period | Changes cost money via `PayToShop` / second chance (`ConfigShops.SecondChancePrice`) | **Missing:** grace policy |
| Deletion needs explicit confirmation and server authorization | Client menu confirm only; server deletes without checks (M5) | **Gap** |
| Clear path back to character selection | Only by reconnecting | **Acceptable** per brief ("after reconnecting") |

**Hooks for extending without forking**

Server:

- `vorp:SelectedCharacter(source, char)` (`user.lua:32`): fires for both new and existing characters.
- `vorp_NewCharacter(source)` (`vorp_character/server/server.lua:128-130`): spoofable via H5, so treat it as a hint, not proof.
- `vorp_core:Server:OnPlayerRespawn` (`apicontroller.lua:221`).
- `vorp_inventory:Server:OnItemUse` (`inventoryService.lua:1347`), for story objects through `registerUsableItem`.

Client:

- `vorp:initNewCharacter` (`client/menu.lua:176`).
- `vorp:SelectedCharacter` (`vorp_core/client/spawnplayer.lua:181`).
- `vorp_core:Client:OnPlayerSpawned` (`spawnplayer.lua:176`).

**Suggested shape:**

1. On server `vorp:SelectedCharacter`, if `rpstack_arrival_story` has no row for `charIdentifier`, move the player to an RPStack routing bucket. This must happen *after* VORP's client sends `instanceplayers 0` (`spawnplayer.lua:192`), so re-assert the bucket.
2. Open RPStack NUI for the Arrival Story. All choices are server-validated.
3. Persist, grant the kit once, and teleport to the chosen arrival point.

---

## 10. Extension strategy

**Allowed without touching `vorp_*` files**

- **Exports:** `vorp_core:GetCore()`, all `vorp_inventory` exports (`registerUsableItem`, `registerInventory`, `addItem`/`subItem`, …), `vorp_police:isOnDuty`.
- **Server-local events:** `vorp:SelectedCharacter`, `vorp:playerJobChange` / `GradeChange` / `GroupChange`, `vorp_NewCharacter`, `vorp_core:Server:OnPlayer*`, `vorp_inventory:Server:OnItem*`.
- **Core services:** `Core.RegisterJobs` for RPStack jobs; `dbUpdateAddTables` is *not* recommended (use rpstack-persistence instead).
- **vorp_lib `Import`** modules for client UX (prompts, points, blips, polyzones).
- **Wrapper resources:** `rpstack-vorp-bridge` (identity, economy-compatible exports, journal). New gameplay modules replace vulnerable VORP gameplay resources rather than extending them, for example an RPStack store and bank in place of `vorp_stores` / `vorp_banking`.

**Where editing VORP seems unavoidable**

1. **Security fixes in resources that cannot simply be disabled.**
   - vorp_core callback registry (H1, H2).
   - vorp_inventory: amount sign checks (C2, C3, H3, M9), name trust in `MoveToCustom` (C4), weapon ownership (H4), pickup distance (M3).
   - vorp_character: `saveCharacter`, `PayToShop`, comp changes (H5, C6, M4).
   - `vorp_lib` DeleteEntity (H8).
   - `vorp_doorlocks`: authorize per-character doors from `GetCore().getUser(src).getUsedCharacter.charIdentifier`, not `Player(src).state.Character.CharId` (H9).
   - A "shield" resource that calls `CancelEvent` to block VORP's net handlers is **rejected** ([ADR-008](../architecture/adr/ADR-008-vorp-patch-policy.md)). Whether `CancelEvent` stops another resource's handler is **[inconclusive]** (A4: the other resource's handler ran first). Even if it did, the protection would depend on handler order across resources, which RPStack does not control. Security fixes go through the patch series.
2. **Resources better disabled and replaced than patched:** `vorp_stores` (C1), `vorp_banking` (C5, H7), the payment paths in `vorp_barbershop` / `vorp_weaponsv2` / `vorp_billing` (M11), `vorp_admin` (M1, M2) if txAdmin is enough for staff.
3. **Config edits:**
   - `vorp_core/config/config.lua`: `initMoney`, `savePlayersTimer`, `MaxCharacters`, `Whitelist`.
   - `vorp_inventory/config/config_server.lua`: `NEW_PLAYER.START_ITEMS` / `START_WEAPONS`.
   - `vorp_character/config.lua`: `SpawnCoords`, `MinAge`, `BannedNames`.
   - Webhook URLs.
   - VORP reads almost nothing from convars, so these are file edits.
4. **Identity model:** the Steam requirement and Steam-keyed `_users` are hard-coded (`whitelist.lua:46-53`, `loadusers.lua:10,127,152`). Changing them means forking core.

**Recommended policy**

- Pin VORP versions and stop txAdmin and auto-updates for VORP.
- Vendor `resources/[VORP]` in its own git repo.
- Keep every change as a numbered patch (`patches/vorp_inventory/0001-positive-amounts.patch`, …), applied by a script and re-applied on each upgrade.
- Upstream the security fixes to VORPCORE to shrink the patch set over time.
- Keep config edits in the same patch series so an update never silently overwrites them.

---

## 11. Runtime verification

One live run of `tests/rpstack-vorp-bridge-smoke` on this server (build 1491, VORP Core 3.3). Commands and method are in `docs/development/testing.md`.

| Check | Result | What it settles |
| --- | --- | --- |
| N1 `getActiveCharacter` (online, invalid source) | PASS | Bridge reads the active character fresh from VORP. |
| N2 `getCharacterById` (online, offline, unknown, invalid) | PASS | Online path via `getUserByCharId` and the read-only offline `SELECT` both work. |
| N3 load/unload events | Observed: character 1 loaded on source 1, unloaded on source 1, character 2 loaded on source 2 | Lifecycle events fire from `vorp:SelectedCharacter` and `playerDropped`, including a reconnect with a different character. The smoke's unload check was corrected to match the previous source of the same player regardless of character id. |
| A1 fresh `getUsedCharacter` | PASS. Fresh read reflected the change; the old snapshot stayed stale (200 vs 201) | **[verified]** Fresh reads work across the export boundary. Snapshots must never be cached (§3.1). |
| A2 `getUsers()[steamId].SaveUser()` | PASS. Callable from another resource; the changed money persisted to `characters.money` and the restore persisted | **[verified]** Forced saves are available for the N5 saga (§8 N5 step 4). |
| A3 client write to own `Player(src).state` | Accepted by the server | **[verified]** Player state bags are client-writable. They must never be used for authorization or identity (H9; `.claude/rules/security.md`; ADR-011). |
| A4 `CancelEvent` across resources | Inconclusive: the other resource's handler ran before the cancelling handler | **[inconclusive]** The question is moot: the shield approach is rejected because any result would depend on handler order (§10; ADR-008). A4 is retired in the smoke resource. |
| A5 same-tick check-then-`removeCurrency` | PASS. 100 iterations, 0 mismatches, local and peer ticks unchanged | **[verified]** Check-then-remove in one tick cannot be interleaved by other handlers or resources (§8 N5 step 2). |

Not covered by the run: the "different character on the same source without reconnecting" path in N3 (only reachable in VORP through repeated character creation, H5).

---

## Top 5 risks

1. **VORP as installed lets an ordinary client mint money and items** (C1–C6, H3–H5). This directly violates RPStack's first vision KPI (V10). Any RPStack economy-adjacent feature, such as faction treasuries, inherits a currency that can be inflated at will. Mitigating it requires patching or disabling VORP resources, which partly contradicts "build without editing VORP".
2. **Patch-maintenance drift.** Securing the base needs edits in vorp_core, vorp_inventory, vorp_character, and vorp_lib. Without pinning and a patch series, a VORP update silently re-opens the exploits and erases config.
3. **No atomic or durable money path.** Money is in-memory floats flushed every 10 minutes, items are write-through, and there is no ledger. Cross-store "atomic" treasury transfers can only be a saga. Forced saves through `SaveUser` work from another resource (A2 **[verified]**), so the saga can close most of the crash window; it remains a saga, not a transaction (§8 N5 step 4).
4. **Identity and authority mismatch.**
   - Steam-only, string-keyed accounts (vs ADR-001).
   - Automatic admin for the first joiner.
   - Two independent admin systems (ACE vs `users.group`), where any moderator can grant `admin` (M2).
   - RPStack permission checks must pick one source of truth.
5. **Untrustworthy VORP channels.** The server→client callback registry can be hijacked or spoofed (H1, H2), player state bags are client-writable **[verified]** (A3; exploitable in VORP's own door locks, H9), and `vorp_NewCharacter` / `vorp:ImDead` are client-driven. RPStack modules must not treat any of these as proof of anything.
   - Related operational exposure: secrets in `server.cfg` and a public listing (`sv_maxclients 48`, tags set) while the critical exploits are live.

## Recommended first implementation step

**Prerequisite (configuration, not code):** keep the server private or whitelisted until C1–C6 are addressed. At minimum, consider stopping `vorp_stores` and `vorp_banking`, which removes C1, C5, and H7 with no code. Also rotate and remove the secrets from `server.cfg`.

**First implementation step:** create `rpstack-vorp-bridge` with **identity only**:

- `getActiveCharacter(src)`, `getCharacterById(id, cb)`, and `characterLoaded` / `characterUnloaded` events (§8 N1–N3).
- A guarded smoke resource that verifies the runtime assumptions this design depends on:
  1. Fresh `getUsedCharacter` closures work across the export boundary. **[verified]**
  2. `getUsers()[id].SaveUser()` is callable from another resource. **[verified]**
  3. Client writes to `Player(src).state` are or aren't accepted. **[verified: accepted]**
  4. `CancelEvent` does or doesn't stop other resources' net handlers. **[inconclusive; approach rejected]**
  5. Same-tick check-and-`removeCurrency` cannot interleave. **[verified]**

This step is now built (`resources/rpstack-vorp-bridge`, `tests/rpstack-vorp-bridge-smoke`) and the results are in "Runtime verification". They confirm the N5 treasury saga is viable as specified.

## Open questions for me

1. **Account key:** accept VORP's Steam hex as the account identity, or keep an RPStack account mapping (`license2` → internal `account_id`) alongside it to honour ADR-001? Characters would use `charidentifier` either way.
2. **Treasury store:** should the bridge re-host economy's owner-account and ledger code (factions keeps calling `rpstack:economy:*` names), or should factions own its treasury table directly?
3. **Patch policy:** are you willing to maintain a VORP security patch series (and upstream it), or would you rather disable and replace the vulnerable resources even where that means rewriting inventory-adjacent flows?
4. **Resources to drop now:** may `vorp_stores`, `vorp_banking`, `vorp_admin`, and the paid paths in `vorp_barbershop` / `vorp_weaponsv2` / `vorp_billing` be stopped on the dev server? Is `vorp_banking`'s per-bank account model wanted at all?
5. **Staff authority:** ACE (cfg-controlled) as the single source for RPStack staff checks, with `users.group` ignored?
6. **Currencies:** dollars only for treasuries, or also gold and rol?
7. **Audit scope:** should RPStack record VORP-internal item movements (via `vorp_inventory:Server:OnItem*` hooks) into an RPStack audit table, given VORP has no ledger and empty webhooks?
8. **Exposure:** is the dev server reachable by people other than you right now? That changes how urgently C1–C6 need action.
9. **Rules conflict:** which export-naming rule is authoritative, `.claude/rules/redm.md` (simple names only) or `CLAUDE.md` / the overview (namespaced allowed with an explicit receiver)? The bridge must pick one.
