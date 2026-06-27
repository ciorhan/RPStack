fx_version 'cerulean'
game 'rdr3'
lua54 'yes'

name 'rpstack-permissions'
author 'RPStack'
description 'RPStack permissions: roles, policy checks, superadmin'
version '0.0.1'

dependency 'rpstack-core'
dependency 'rpstack-persistence'
dependency 'rpstack-identity'

shared_scripts {
  'shared/*.lua',
}

server_scripts {
  'config/server.lua',
  'server/state.lua',
  'server/repositories/permissions_repo.lua',
  'server/permissions.lua',
  'server/exports.lua',
  'server/main.lua',
}