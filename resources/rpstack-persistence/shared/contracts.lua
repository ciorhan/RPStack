-- Contracts for rpstack-persistence public exports.

RPSTACK_PERSISTENCE_CONTRACTS = {

  -- rpstack:persistence:registerMigration(resource, name, sql)
  -- Call this before rpstack:persistence:ready fires.
  -- Migrations are applied once and tracked in _rpstack_migrations.
  registerMigration = {
    input  = { "resource:string", "name:string", "sql:string" },
    output = { },
    async  = false,
    notes  = "sql must be idempotent (IF NOT EXISTS etc.)",
  },

  -- rpstack:persistence:isReady() → boolean
  -- Returns true only after migrations have completed successfully.
  isReady = {
    input  = { },
    output = { "ready:boolean" },
    async  = false,
  },
}

-- Internal event (not an export):
-- "rpstack:persistence:ready" — fired once after all migrations complete.
-- Other resources listen for this before registering event handlers.