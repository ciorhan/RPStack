-- rpstack-vorp-bridge/server/repository.lua
--
-- SANCTIONED CROSS-MODULE READ (ADR-005, docs/architecture/overview.md "VORP deployment").
-- This is the only RPStack query against a VORP-owned table. It is read-only,
-- parameterized, and selects a fixed column list. The bridge never writes VORP tables.

RPSTACK_BRIDGE_REPO = {}

function RPSTACK_BRIDGE_REPO.findCharacterById(characterId, cb)
  RPSTACK_DB.single(
    "SELECT charidentifier, firstname, lastname FROM characters WHERE charidentifier = ? LIMIT 1",
    { characterId },
    cb
  )
end
