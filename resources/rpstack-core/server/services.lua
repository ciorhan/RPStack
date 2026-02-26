RPSTACK_SERVICES = RPSTACK_SERVICES or {}

local services = {}

function RPSTACK_SERVICES.register(name, service)
  assert(type(name) == "string" and name ~= "", "service name required")
  assert(service ~= nil, "service instance required")
  assert(services[name] == nil, ("service already registered: %s"):format(name))

  services[name] = service
  if RPSTACK_LOG then RPSTACK_LOG.info("core", "service registered", { name = name }) end
end

function RPSTACK_SERVICES.get(name)
  return services[name]
end