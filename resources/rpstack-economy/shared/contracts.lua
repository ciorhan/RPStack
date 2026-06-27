-- Contracts for rpstack-economy public exports.
-- All exports are async. Caller must provide a callback as the last argument.
-- Requires an active character on source (via rpstack:identity:selectCharacter).

RPSTACK_ECONOMY_CONTRACTS = {

  -- rpstack:economy:getBalance(source, cb)
  -- cb({ ok, cash, bank, error })
  getBalance = {
    input  = { "source:number", "cb:function" },
    output = { "ok:boolean", "cash:number|nil", "bank:number|nil", "error:string|nil" },
    async  = true,
  },

  -- rpstack:economy:addMoney(source, account, amount, reason, cb)
  -- account = "cash" | "bank"
  -- amount  = positive integer, max RPSTACK_ECONOMY_CONFIG.maxTransactionAmount
  -- cb({ ok, cash, bank, error })
  addMoney = {
    input  = { "source:number", "account:string", "amount:number", "reason:string", "cb:function" },
    output = { "ok:boolean", "cash:number|nil", "bank:number|nil", "error:string|nil" },
    async  = true,
  },

  -- rpstack:economy:removeMoney(source, account, amount, reason, cb)
  removeMoney = {
    input  = { "source:number", "account:string", "amount:number", "reason:string", "cb:function" },
    output = { "ok:boolean", "cash:number|nil", "bank:number|nil", "error:string|nil" },
    async  = true,
  },

  -- rpstack:economy:deposit(source, amount, reason, cb)
  -- Moves amount from cash → bank atomically (two ledger entries).
  deposit = {
    input  = { "source:number", "amount:number", "reason:string", "cb:function" },
    output = { "ok:boolean", "cash:number|nil", "bank:number|nil", "error:string|nil" },
    async  = true,
  },

  -- rpstack:economy:withdraw(source, amount, reason, cb)
  -- Moves amount from bank → cash atomically (two ledger entries).
  withdraw = {
    input  = { "source:number", "amount:number", "reason:string", "cb:function" },
    output = { "ok:boolean", "cash:number|nil", "bank:number|nil", "error:string|nil" },
    async  = true,
  },
}

-- Internal event (not an export):
-- "rpstack:identity:characterCreated" (char_id) — economy listens to auto-create balance row.