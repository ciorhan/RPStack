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
  -- Moves amount from cash to bank using two ledger entries.
  deposit = {
    input  = { "source:number", "amount:number", "reason:string", "cb:function" },
    output = { "ok:boolean", "cash:number|nil", "bank:number|nil", "error:string|nil" },
    async  = true,
  },

  -- rpstack:economy:withdraw(source, amount, reason, cb)
  -- Moves amount from bank to cash using two ledger entries.
  withdraw = {
    input  = { "source:number", "amount:number", "reason:string", "cb:function" },
    output = { "ok:boolean", "cash:number|nil", "bank:number|nil", "error:string|nil" },
    async  = true,
  },

  createAccountForOwner = {
    input = { "ownerType:string", "ownerId:number", "accountType:string", "cb:function" },
    output = { "ok:boolean", "account:table|nil", "error:string|nil" },
    async = true,
  },

  getAccountByOwner = {
    input = { "ownerType:string", "ownerId:number", "accountType:string", "cb:function" },
    output = { "ok:boolean", "account:table|nil", "error:string|nil" },
    async = true,
  },

  adjustOwnerCash = {
    input = { "ownerType:string", "ownerId:number", "accountType:string", "delta:number", "reason:string", "cb:function" },
    output = { "ok:boolean", "newCash:number|nil", "error:string|nil" },
    async = true,
  },

  adjustCashByCharId = {
    input = { "characterId:number", "delta:number", "reason:string", "cb:function" },
    output = { "ok:boolean", "newCash:number|nil", "error:string|nil" },
    async = true,
  },

  transferCash = {
    input = {
      "fromType:string", "fromId:number", "fromAccount:string",
      "toType:string", "toId:number", "toAccount:string",
      "amount:number", "reason:string", "cb:function",
    },
    output = {
      "ok:boolean", "sourceCash:number|nil",
      "destinationCash:number|nil", "error:string|nil",
    },
    async = true,
    notes = "Performs the debit and credit in one atomic SQL update.",
  },
}

-- Internal event (not an export):
-- "rpstack:identity:characterCreated" (char_id) — economy listens to auto-create balance row.