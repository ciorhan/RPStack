fx_version 'cerulean'
game 'rdr3'

lua54 'yes'

shared_scripts {
  'shared/constants.lua',
  'shared/config.lua',
}

server_scripts {
  -- IMPORTANT: load order matters
  '@oxmysql/lib/MySQL.lua', -- if you use oxmysql; remove if not
  'server/services/util.lua',
  'server/services/log.lua',
  'server/services/ratelimit.lua',
  'server/services/db.lua',
  'server/services/rpc.lua',
  'server/player/identifiers.lua',
  'server/player/registry.lua',
  'server/bootstrap.lua',
  'server/main.lua',
}

client_scripts {
  'client/main.lua',
}