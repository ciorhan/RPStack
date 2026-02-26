Identifiers = {}

function Identifiers.get(source)
  local out = {
    license = nil,
    license2 = nil,
    steam = nil,
    discord = nil,
    fivem = nil,
    ip = nil,
  }

  for i = 0, GetNumPlayerIdentifiers(source) - 1 do
    local id = GetPlayerIdentifier(source, i)
    if id:find('license:') == 1 then out.license = id
    elseif id:find('license2:') == 1 then out.license2 = id
    elseif id:find('steam:') == 1 then out.steam = id
    elseif id:find('discord:') == 1 then out.discord = id
    elseif id:find('fivem:') == 1 then out.fivem = id
    end
  end

  out.ip = GetPlayerEndpoint(source)
  return out
end