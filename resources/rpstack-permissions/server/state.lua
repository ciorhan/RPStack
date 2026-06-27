RPSTACK_PERMISSIONS_STATE = RPSTACK_PERMISSIONS_STATE or {}

-- Cache per account_id: { roles = { "admin", ... }, permissions = { "economy.give" = true, ... } }
RPSTACK_PERMISSIONS_STATE.cache = RPSTACK_PERMISSIONS_STATE.cache or {}