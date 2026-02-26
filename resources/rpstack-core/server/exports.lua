-- Exported APIs should be stable, namespaced, and return consistent shapes.

exports('rpstack:core:ping', function()
  return {
    ok = true,
    env = (RPSTACK_CONFIG and RPSTACK_CONFIG.env) or "unknown",
    time = os.time(),
  }
end)