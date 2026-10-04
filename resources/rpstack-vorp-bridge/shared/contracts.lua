-- rpstack-vorp-bridge/shared/contracts.lua
-- Documents every public export and emitted event: input, output shape, error codes.
-- Not enforced at runtime in v0 — serves as authoritative API reference.

RPSTACK_BRIDGE_CONTRACTS = {

  ["rpstack:identity:getActiveCharacter"] = {
    input  = { "src:number (final player source)" },
    output = { "ok:boolean", "character:table|nil {id:number, firstname:string, lastname:string}", "error:string|nil" },
    errors = { "VALIDATION_FAILED", "NOT_FOUND", "INTERNAL" },
    notes  = "SYNC. Reads VORP fresh on every call via GetCore().getUser(src).getUsedCharacter. Never reads state bags.",
  },

  ["rpstack:identity:getCharacterById"] = {
    input  = { "characterId:number (VORP charidentifier)", "cb:function" },
    output = { "ok:boolean", "character:table|nil {id:number, firstname:string, lastname:string, online:boolean}", "error:string|nil" },
    errors = { "VALIDATION_FAILED", "NOT_FOUND", "INTERNAL" },
    notes  = "ASYNC. Online characters come from GetCore().getUserByCharId; offline ones from one read-only SELECT on VORP's characters table.",
  },
}

RPSTACK_BRIDGE_EVENT_CONTRACTS = {

  ["rpstack:identity:characterLoaded"] = {
    payload = { "characterId:number", "source:number" },
    notes   = "Server-local. Emitted when VORP activates a character for a source. If the source already had a different character, characterUnloaded is emitted for it first.",
  },

  ["rpstack:identity:characterUnloaded"] = {
    payload = { "characterId:number", "source:number" },
    notes   = "Server-local. Emitted from the bridge's own map on playerDropped, or before a different character is loaded for the same source.",
  },
}
