fx_version 'cerulean'
game 'rdr3'
lua54 'yes'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'rpstack-persistence'
author 'RPStack'
description 'RPStack persistence: oxmysql wrapper, migration runner, repository base'
version '0.0.1'

dependency 'rpstack-core'

shared_scripts {
  'shared/*.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'config/server.lua',
  'server/db.lua',
  'server/migrations.lua',
  'server/exports.lua',
  'server/main.lua',
}

