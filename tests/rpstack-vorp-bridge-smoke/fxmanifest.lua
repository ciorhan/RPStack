fx_version 'cerulean'
game 'rdr3'
lua54 'yes'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'rpstack-vorp-bridge-smoke'
author 'RPStack'
description 'Console-only local smoke tests for rpstack-vorp-bridge and VORP runtime assumptions'
version '0.0.1'

dependencies {
  'vorp_core',
  'rpstack-persistence',
  'rpstack-vorp-bridge',
}

server_scripts {
  'server/util.lua',
  'server/bridge_checks.lua',
  'server/assumptions.lua',
}

-- Only reacts to server-triggered smoke events; the server never sends them
-- unless rpstack:smoke:enabled is 1.
client_script 'client/main.lua'
