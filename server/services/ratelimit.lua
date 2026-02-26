RateLimit = {
  buckets = {}, -- buckets[source][route] = { count, resetAt }
}

local function key(source, route)
  return tostring(source) .. ':' .. route
end

function RateLimit.check(source, route, limit, windowMs)
  limit = limit or Config.RateLimit.default.limit
  windowMs = windowMs or Config.RateLimit.windowMs

  local t = Util.ms()
  local k = key(source, route)

  local b = RateLimit.buckets[k]
  if not b or t >= b.resetAt then
    b = { count = 0, resetAt = t + windowMs }
    RateLimit.buckets[k] = b
  end

  b.count = b.count + 1
  if b.count > limit then
    return false, { remaining = 0, resetAt = b.resetAt }
  end

  return true, { remaining = limit - b.count, resetAt = b.resetAt }
end