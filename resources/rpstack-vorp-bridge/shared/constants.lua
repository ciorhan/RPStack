-- rpstack-vorp-bridge/shared/constants.lua
-- Event names and VORP identifiers used by the bridge.

BRIDGE_EVENTS = {
  -- Emitted by the bridge with the same names and payloads as rpstack-identity,
  -- so existing listeners (for example rpstack-factions) work unchanged.
  CHARACTER_LOADED   = "rpstack:identity:characterLoaded",
  CHARACTER_UNLOADED = "rpstack:identity:characterUnloaded",
  READY              = "rpstack:bridge:ready",
}

BRIDGE_VORP = {
  RESOURCE                 = "vorp_core",
  -- Server-local event fired by vorp_core when a character becomes active:
  -- TriggerEvent("vorp:SelectedCharacter", source, characterTable)
  -- (vorp_core/server/class/user.lua:32)
  EVENT_SELECTED_CHARACTER = "vorp:SelectedCharacter",
}
