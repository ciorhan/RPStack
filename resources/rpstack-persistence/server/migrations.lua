-- migrations.lua
-- Tracks and applies SQL migrations in order.
-- Each resource registers its migrations here at startup.
-- Migrations must be idempotent (IF NOT EXISTS, etc.).

RPSTACK_MIGRATIONS = {}

local pending = {} -- { { resource, name, sql }, ... }

-- Called by other resources to register a migration.
-- resource: string identifier e.g. "rpstack-identity"
-- name:     unique migration name e.g. "001_create_accounts"
-- sql:      the SQL to execute
function RPSTACK_MIGRATIONS.register(resource, name, sql)
  assert(type(resource) == "string" and resource ~= "", "migration: resource name required")
  assert(type(name) == "string" and name ~= "",         "migration: name required")
  assert(type(sql) == "string" and sql ~= "",           "migration: sql required")
  pending[#pending + 1] = { resource = resource, name = name, sql = sql }
end

-- Run all registered migrations that haven't been applied yet.
-- Calls cb(ok, err) when done.
function RPSTACK_MIGRATIONS.run(cb)
  -- Ensure the tracking table exists first
  MySQL.update([[
    CREATE TABLE IF NOT EXISTS `_rpstack_migrations` (
      `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `resource`   VARCHAR(64)  NOT NULL,
      `name`       VARCHAR(128) NOT NULL,
      `applied_at` DATETIME     DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uq_migration` (`resource`, `name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]], {}, function()

    -- Fetch already-applied migrations
    MySQL.query("SELECT resource, name FROM `_rpstack_migrations`", {}, function(rows)
      local applied = {}
      for _, row in ipairs(rows or {}) do
        applied[row.resource .. ":" .. row.name] = true
      end

      -- Apply pending migrations sequentially
      local function applyNext(i)
        if i > #pending then
          RPSTACK_LOG.info("persistence", "migrations complete", { total = #pending })
          cb(true, nil)
          return
        end

        local m = pending[i]
        local key = m.resource .. ":" .. m.name

        if applied[key] then
          applyNext(i + 1)
          return
        end

        RPSTACK_LOG.info("persistence", "applying migration", { resource = m.resource, name = m.name })

        MySQL.update(m.sql, {}, function(ok)
          if not ok and ok ~= 0 then
            local err = ("migration failed: %s/%s"):format(m.resource, m.name)
            RPSTACK_LOG.error("persistence", err)
            cb(false, err)
            return
          end

          MySQL.update(
            "INSERT IGNORE INTO `_rpstack_migrations` (resource, name) VALUES (?, ?)",
            { m.resource, m.name },
            function()
              applyNext(i + 1)
            end
          )
        end)
      end

      applyNext(1)
    end)
  end)
end