RPSTACK_IDENTITY_CONFIG = RPSTACK_IDENTITY_CONFIG or {}

-- Placeholder values; later you’ll wire persistence (Postgres/Mongo/etc)
RPSTACK_IDENTITY_CONFIG.autoCreateCharacter = (GetConvar('rpstack:identity:autoCreateCharacter', 'false') == 'true')
RPSTACK_IDENTITY_CONFIG.defaultSpawn = {
  x = tonumber(GetConvar('rpstack:identity:spawn:x', '0.0')),
  y = tonumber(GetConvar('rpstack:identity:spawn:y', '0.0')),
  z = tonumber(GetConvar('rpstack:identity:spawn:z', '0.0')),
}