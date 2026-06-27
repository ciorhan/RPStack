RPSTACK_PERMISSIONS_CONFIG = {}

-- Comma-separated list of primary identifiers that bypass all permission checks.
-- Set in server.cfg: set rpstack:permissions:superadmins "license:abc123,license:def456"
local raw = GetConvar('rpstack:permissions:superadmins', '')
RPSTACK_PERMISSIONS_CONFIG.superadmins = {}
for id in raw:gmatch('[^,]+') do
  local trimmed = id:match('^%s*(.-)%s*$')
  if trimmed ~= '' then
    RPSTACK_PERMISSIONS_CONFIG.superadmins[trimmed] = true
  end
end

-- Default roles created on first run
RPSTACK_PERMISSIONS_CONFIG.defaultRoles = {
  { name = 'superadmin', label = 'Super Admin' },
  { name = 'admin',      label = 'Admin'       },
  { name = 'moderator',  label = 'Moderator'   },
  { name = 'player',     label = 'Player'      },
}