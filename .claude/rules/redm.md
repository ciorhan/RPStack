# RedM Runtime Rules

## Cfx.re specifics

- `source` is a magic global. Capture immediately: `local src = source`. Never use after a yield/await.
- `GetPlayerIdentifier(src, i)` returns `nil` for out-of-range — always bounds-check with `GetNumPlayerIdentifiers`.
- `playerJoining` fires before `playerConnecting` completes deferrals. Use `playerConnecting` for screening.
- `Citizen.CreateThread` / `CreateThread` — yielding inside event handlers requires explicit thread creation.
- `Wait(0)` yields one tick. Never busy-loop without a wait.
- `exports[resource]:fn()` calls cross-resource synchronously on the same side (server→server, client→client only).
- State bags (`Entity(0).state`) replicate server→client automatically. Don't use for secrets.

## RedM vs FiveM differences

- Many FiveM natives do not exist in RedM. Verify every native at: https://alloc8or.re/rdr3/nativedb/
- `PLAYER` namespace natives behave differently in RDR3. Do not assume FiveM behavior.
- `rdr3` game declaration required in fxmanifest, not `gta5`.
- `fx_version 'cerulean'` is current standard.

## fxmanifest rules

- `lua54 'yes'` must be declared to use Lua 5.4 features (integer division, bitwise ops, `<const>`, `<close>`).
- Load order within a resource is determined by array order in `server_scripts {}`.
- `dependency 'rpstack-core'` ensures core is started first — always declare it.
- Never load server files as shared scripts or vice versa.

## Verified native sources

- RDR3 natives: https://alloc8or.re/rdr3/nativedb/
- Cfx.re docs: https://docs.fivem.net/docs/scripting-reference/ (note FiveM-focused, verify RedM compat)
- Do not invent natives. If uncertain, mark as UNVERIFIED and research before use.
