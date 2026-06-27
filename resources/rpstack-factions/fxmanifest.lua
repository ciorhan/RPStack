fx_version 'cerulean'
game 'rdr3'
lua54 'yes'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'rpstack-factions'
author 'RPStack'
description 'RPStack factions: multi-faction membership, ranks, relationships, treasury'
version '0.0.1'

dependencies {
  'rpstack-core',
  'rpstack-persistence',
  'rpstack-identity',
  'rpstack-economy',
}

shared_scripts {
  'shared/logger.lua',
  'shared/db.lua',
  'shared/constants.lua',
  'shared/contracts.lua',
}

server_scripts {
  'config/server.lua',
  'server/state.lua',
  'server/repository.lua',
  'server/cache.lua',
  'server/audit.lua',
  'server/ranks.lua',
  'server/faction.lua',
  'server/membership.lua',
  'server/relationships.lua',
  'server/treasury.lua',
  'server/exports.lua',
  'server/main.lua',
}

client_scripts {
  'client/main.lua',
}
