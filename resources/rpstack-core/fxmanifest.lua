fx_version 'cerulean'
game 'rdr3'

name 'rpstack-core'
author 'RPStack'
description 'RPStack core runtime: config, logging, contracts, service registry'
version '0.0.1'

shared_scripts {
  'shared/*.lua',
}

server_scripts {
  'config/server.lua',
  'server/logger.lua',
  'server/services.lua',
  'server/exports.lua',
  'server/main.lua',
}

client_scripts {
  'client/main.lua',
}