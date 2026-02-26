RPSTACK_IDENTITY_CONTRACTS = {
  -- Export: rpstack:identity:getSession(source)
  getSession = {
    input = { "source:number" },
    output = { "ok:boolean", "session:table|nil", "error:string|nil" },
  },

  -- Export: rpstack:identity:createCharacter(source, payload)
  createCharacter = {
    input = { "source:number", "payload:table" },
    output = { "ok:boolean", "character:table|nil", "error:string|nil" },
  },

  -- Export: rpstack:identity:getActiveCharacter(source)
  getActiveCharacter = {
    input = { "source:number" },
    output = { "ok:boolean", "character:table|nil", "error:string|nil" },
  },
}