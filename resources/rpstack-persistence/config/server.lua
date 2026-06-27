RPSTACK_PERSISTENCE_CONFIG = {}

-- Log queries slower than this threshold (milliseconds)
RPSTACK_PERSISTENCE_CONFIG.slowQueryMs = tonumber(GetConvar('rpstack:persistence:slowQueryMs', '50'))