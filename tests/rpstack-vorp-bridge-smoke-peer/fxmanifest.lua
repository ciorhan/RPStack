fx_version 'cerulean'
game 'rdr3'
lua54 'yes'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'rpstack-vorp-bridge-smoke-peer'
author 'RPStack'
description 'Second resource for rpstack-vorp-bridge-smoke cross-resource checks (A5)'
version '0.0.1'

-- Starts after the smoke resource.
dependency 'rpstack-vorp-bridge-smoke'

server_script 'server/main.lua'
