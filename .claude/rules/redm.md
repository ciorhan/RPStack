# RedM Runtime Rules

## CfxLua resource isolation (critical)

Each resource runs in a completely isolated Lua environment. This has major consequences:

- **Globals never cross resource boundaries.** A global set in `rpstack-core` is invisible in `rpstack-identity`. Always use exports or events to share data.
- **Every resource that needs logging must load its own `shared/logger.lua`.**
- **Every resource that needs DB access must load its own `shared/db.lua`** which delegates to persistence exports.
- **Export functions are the only cross-resource communication mechanism** (aside from events).

## Export syntax (verified in production)

```lua
-- CORRECT: colon syntax
exports['rpstack-persistence']:registerMigration(name, sql)
exports['rpstack-identity']:getSession(src)

-- WRONG: bracket syntax silently drops the first argument
exports['rpstack-persistence']['registerMigration'](name, sql)  -- sql arrives as nil
```

Export names must be simple strings — no colons, no namespacing:

```lua
-- CORRECT
exports('registerMigration', function(name, sql) ... end)
exports('getSession', function(src) ... end)

-- WRONG — causes argument shifting
exports('rpstack:persistence:registerMigration', function(...) ... end)
```

## String passing across exports

Multiline strings `[[...]]` fail silently when passed across resource export boundaries — they arrive as nil. Always use single-line quoted strings for SQL and other long values passed via exports.

## Startup sequencing

Resources must wait for `rpstack:persistence:ready` before registering handlers. Wrap the handler body in a thread to ensure all globals are initialized:

```lua
AddEventHandler('rpstack:persistence:ready', function()
  CreateThread(function()
    Wait(0)
    -- safe to use RPSTACK_LOG, RPSTACK_DB here
  end)
end)
```

## fxmanifest requirements (verified)

```lua
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
```

`rdr3_warning` is mandatory — resource won't start without it. Place it first.

## Cfx.re specifics

- `source` is a magic global. Capture immediately: `local src = source`. Never use after a yield.
- `GetPlayerIdentifier(src, i)` returns `nil` for out-of-range — always bounds-check.
- Use `playerConnecting` with deferrals for connection screening, not `playerJoining`.
- `CreateThread` / `Wait(0)` — yielding inside event handlers requires explicit thread creation.
- Never busy-loop without a `Wait`.

## System resources required for RedM

Copy from `cfx-server-data` into your resources folder:

```
sessionmanager-rdr3
mapmanager
spawnmanager
hardcap
```

Ensure them in server.cfg before any framework resources. `sessionmanager` (FiveM version) must be stopped:

```
stop sessionmanager
ensure sessionmanager-rdr3
```

## RedM vs FiveM differences

- Many FiveM natives do not exist in RedM. Verify at: https://alloc8or.re/rdr3/nativedb/
- Do not assume FiveM behavior for any native. Test everything.
- `rdr3` game declaration required, not `gta5`.

## Verified sources

- RDR3 natives: https://alloc8or.re/rdr3/nativedb/
- Cfx.re docs: https://docs.fivem.net/docs/scripting-reference/
- Do not invent natives. Mark uncertain findings as UNVERIFIED.
