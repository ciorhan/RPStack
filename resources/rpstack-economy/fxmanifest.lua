fx_version 'cerulean'
game 'rdr3'
lua54 'yes'

name 'rpstack-economy'
author 'RPStack'
description 'RPStack economy: cash + bank balances, transaction ledger, audit trail'
version '0.0.1'

dependency 'rpstack-core'
dependency 'rpstack-persistence'
dependency 'rpstack-identity'

server_scripts {
  'config/server.lua',
  'server/repositories/economy_repo.lua',
  'server/ledger.lua',
  'server/exports.lua',
  'server/main.lua',
}

shared_scripts {
  'shared/*.lua',
}