-- Minimal config loader pattern for v0.
-- Later: read JSON + allow overrides via convars.

RPSTACK_CONFIG = RPSTACK_CONFIG or {}

RPSTACK_CONFIG.env = GetConvar('rpstack:env', 'dev')
RPSTACK_CONFIG.logLevel = GetConvar('rpstack:logLevel', 'info')