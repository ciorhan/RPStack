fx_version 'cerulean'
game 'rdr3'
lua54 'yes'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'rpstack-vorp-bridge'
author 'RPStack'
description 'RPStack VORP bridge: identity-compatible exports over VORP Core'
version '0.0.1'

dependencies {
  'vorp_core',
  'rpstack-core',
  'rpstack-persistence',
}

shared_scripts {
  'shared/logger.lua',
  'shared/db.lua',
  'shared/errors.lua',
  'shared/constants.lua',
  'shared/contracts.lua',
}

server_scripts {
  'config/server.lua',
  'server/state.lua',
  'server/vorp.lua',
  'server/repository.lua',
  'server/identity.lua',
  'server/exports.lua',
  'server/main.lua',
}
