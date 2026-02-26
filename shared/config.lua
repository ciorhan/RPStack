Config = Config or {}

Config.FrameworkName = 'rp'
Config.Debug = true

Config.RateLimit = {
  -- tokens per window
  windowMs = 10_000,
  default = { limit = 25 }, -- 25 requests / 10s per player per route
}

Config.DB = {
  enabled = true,
}