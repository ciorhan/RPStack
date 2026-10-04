-- rpstack-vorp-bridge/server/state.lua
-- In-memory state owned by the bridge.
--
-- charBySource[src] = characterId
--   Lifecycle: set on vorp:SelectedCharacter (after re-reading VORP), cleared on
--   playerDropped. Rebuilt from VORP on resource start (no events emitted).
--   Used only to emit characterUnloaded; exports always read VORP fresh.

RPSTACK_BRIDGE_STATE = {
  charBySource = {},
  started = false,
}
