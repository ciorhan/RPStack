fx_version 'cerulean'
game 'rdr3'

name 'rpstack-identity'
author 'RPStack'
description 'RPStack identity: sessions, characters (create/load/save), identity mapping'
version '0.0.1'

dependency 'rpstack-core'

shared_scripts {
  'shared/*.lua',
}

server_scripts {
  'config/server.lua',
  'server/state.lua',
  'server/session.lua',
  'server/character.lua',
  'server/exports.lua',
  'server/main.lua',
}

client_scripts {
  'client/main.lua',
}