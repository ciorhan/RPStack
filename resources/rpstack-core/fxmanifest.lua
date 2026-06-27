rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

fx_version 'cerulean'
game 'rdr3'
lua54 'yes'

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