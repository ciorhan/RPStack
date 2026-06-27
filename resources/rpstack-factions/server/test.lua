-- Temporary test file — delete after Layer 2 testing
CreateThread(function()
  Wait(5000) -- wait 5s for everything to be ready

  print("[TEST] listFactions: " .. json.encode(exports['rpstack-factions']:listFactions()))

  exports['rpstack-factions']:createFaction({
    name = "Blackwater Law",
    tag = "LAW",
    type = "law",
    founderCharId = 1
  }, function(r)
    print("[TEST] createFaction: " .. json.encode(r))

    print("[TEST] getFactionByTag: " .. json.encode(exports['rpstack-factions']:getFactionByTag("LAW")))
    print("[TEST] getRanks: " .. json.encode(exports['rpstack-factions']:getRanks(1)))
    print("[TEST] isMember: " .. json.encode(exports['rpstack-factions']:isMember(1, 1)))
    print("[TEST] hasPerm disband: " .. json.encode(exports['rpstack-factions']:characterHasFactionPerm(1, 1, "can_disband")))
    print("[TEST] hasPerm deposit: " .. json.encode(exports['rpstack-factions']:characterHasFactionPerm(1, 1, "can_deposit")))
  end)
end)