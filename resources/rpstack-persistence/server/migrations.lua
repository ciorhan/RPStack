RPSTACK_MIGRATIONS = {}

local pending = {}

function RPSTACK_MIGRATIONS.register(name, sql)
  assert(type(name) == "string" and name ~= "", "migration: name required")
  assert(type(sql) == "string" and sql ~= "",   "migration: sql required")
  pending[#pending + 1] = { name = name, sql = sql }
end

function RPSTACK_MIGRATIONS.run(cb)
  MySQL.update(
    "CREATE TABLE IF NOT EXISTS `_rpstack_migrations` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `name` VARCHAR(128) NOT NULL, `applied_at` DATETIME DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE KEY `uq_name` (`name`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    {},
    function()
      MySQL.query("SELECT name FROM `_rpstack_migrations`", {}, function(rows)
        local applied = {}
        for _, row in ipairs(rows or {}) do
          applied[row.name] = true
        end

        local function applyNext(i)
          if i > #pending then
            print("[rpstack-persistence] migrations complete, total=" .. #pending)
            cb(true, nil)
            return
          end

          local m = pending[i]

          if applied[m.name] then
            applyNext(i + 1)
            return
          end

          print("[rpstack-persistence] applying migration: " .. m.name)

          MySQL.update(m.sql, {}, function(ok)
            if not ok and ok ~= 0 then
              local err = "migration failed: " .. m.name
              print("[rpstack-persistence] ERROR: " .. err)
              cb(false, err)
              return
            end

            MySQL.update(
              "INSERT IGNORE INTO `_rpstack_migrations` (name) VALUES (?)",
              { m.name },
              function()
                applyNext(i + 1)
              end
            )
          end)
        end

        applyNext(1)
      end)
    end
  )
end