-- Contracts for rpstack-identity public exports.
-- These are documentation + runtime reference, not enforced schemas (yet).
-- All async exports require a callback as the last argument.

RPSTACK_IDENTITY_CONTRACTS = {

  -- rpstack:identity:getSession(source) → { ok, session, error }
  -- session = { source, account_id, primaryIdentifier, name, joinedAt }
  getSession = {
    input  = { "source:number" },
    output = { "ok:boolean", "session:table|nil", "error:string|nil" },
    async  = false,
  },

  -- rpstack:identity:getCharacters(source, cb)
  -- cb({ ok, characters:table[], error })
  -- characters = [{ id, account_id, first_name, last_name, created_at }]
  getCharacters = {
    input  = { "source:number", "cb:function" },
    output = { "ok:boolean", "characters:table[]", "error:string|nil" },
    async  = true,
  },

  -- rpstack:identity:createCharacter(source, payload, cb)
  -- payload = { firstName:string(2-24), lastName:string(2-24) }
  -- cb({ ok, character, error })
  createCharacter = {
    input  = { "source:number", "payload:table", "cb:function" },
    output = { "ok:boolean", "character:table|nil", "error:string|nil" },
    async  = true,
  },

  -- rpstack:identity:selectCharacter(source, char_id, cb)
  -- Verifies ownership before activating. cb({ ok, character, error })
  selectCharacter = {
    input  = { "source:number", "char_id:number", "cb:function" },
    output = { "ok:boolean", "character:table|nil", "error:string|nil" },
    async  = true,
  },

  -- rpstack:identity:getActiveCharacter(source) → { ok, character|nil }
  -- Returns the currently selected character from in-memory state (fast, sync).
  getActiveCharacter = {
    input  = { "source:number" },
    output = { "ok:boolean", "character:table|nil" },
    async  = false,
  },

  getCharacterById = {
    input = { "characterId:number", "cb:function" },
    output = { "ok:boolean", "character:table|nil", "error:string|nil" },
    async = true,
  },
}