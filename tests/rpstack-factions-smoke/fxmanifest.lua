fx_version 'cerulean'
game 'rdr3'
lua54 'yes'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'rpstack-factions-smoke'
author 'RPStack'
description 'Console-only local smoke tests for factions'
version '0.0.1'

dependencies {
  'rpstack-identity',
  'rpstack-economy',
  'rpstack-factions',
}

server_script 'server/main.lua'
