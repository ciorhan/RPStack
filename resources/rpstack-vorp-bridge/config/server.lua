-- rpstack-vorp-bridge/config/server.lua

RPSTACK_BRIDGE_CONFIG = {
  -- Upper bound for VORP charidentifier values accepted at the export boundary.
  -- VORP stores charidentifier as INT(11) (signed), see characters table.
  max_character_id = 2147483647,
}
