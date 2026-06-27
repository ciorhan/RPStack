fx_version 'cerulean'
game 'rdr3'
lua54 'yes'

name 'rpstack-identity'
author 'RPStack'
description 'RPStack identity: accounts, sessions, multi-character'
version '0.0.1'

dependency 'rpstack-core'
dependency 'rpstack-persistence'

shared_scripts {
  'shared/*.lua',
}

server_scripts {
  'config/server.lua',
  'server/state.lua',
  'server/repositories/account_repo.lua',
  'server/repositories/character_repo.lua',
  'server/session.lua',
  'server/character.lua',
  'server/exports.lua',
  'server/main.lua',
}

client_scripts {
  'client/main.lua',
}