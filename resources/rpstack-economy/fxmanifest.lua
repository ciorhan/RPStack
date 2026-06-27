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

shared_scripts {
  'shared/*.lua',
}

server_scripts {
  'config/server.lua',
  'server/repositories/economy_repo.lua',
  'server/ledger.lua',
  'server/exports.lua',
  'server/main.lua',
}

