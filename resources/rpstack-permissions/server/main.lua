-- Register migrations
exports['rpstack-persistence']['rpstack:persistence:registerMigration'](
  'rpstack-permissions',
  '001_create_roles',
  [[
    CREATE TABLE IF NOT EXISTS `rpstack_roles` (
      `id`    INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `name`  VARCHAR(32)  NOT NULL,
      `label` VARCHAR(64)  NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uq_name` (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]]
)

exports['rpstack-persistence']['rpstack:persistence:registerMigration'](
  'rpstack-permissions',
  '002_create_role_permissions',
  [[
    CREATE TABLE IF NOT EXISTS `rpstack_role_permissions` (
      `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `role_id`    INT UNSIGNED NOT NULL,
      `permission` VARCHAR(64)  NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uq_role_perm` (`role_id`, `permission`),
      INDEX `idx_role_id` (`role_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]]
)

exports['rpstack-persistence']['rpstack:persistence:registerMigration'](
  'rpstack-permissions',
  '003_create_account_roles',
  [[
    CREATE TABLE IF NOT EXISTS `rpstack_account_roles` (
      `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `account_id` INT UNSIGNED NOT NULL,
      `role_id`    INT UNSIGNED NOT NULL,
      `created_at` DATETIME     DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uq_account_role` (`account_id`, `role_id`),
      INDEX `idx_account_id` (`account_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]]
)

AddEventHandler('rpstack:persistence:ready', function()
  RPSTACK_LOG.info("permissions", "rpstack-permissions starting")

  -- Seed default roles
  RPSTACK_PERMISSIONS_REPO.seedRoles(RPSTACK_PERMISSIONS_CONFIG.defaultRoles, function()
    RPSTACK_LOG.info("permissions", "default roles seeded")

    -- Load permissions cache when a player connects
    AddEventHandler('rpstack:identity:sessionCreated', function(src, account_id)
      RPSTACK_PERMISSIONS.loadForAccount(account_id, function()
        RPSTACK_LOG.debug("permissions", "cache loaded", { account_id = account_id })
      end)
    end)

    -- Clear cache on disconnect
    AddEventHandler('rpstack:identity:sessionDropped', function(src, account_id)
      RPSTACK_PERMISSIONS.clearForAccount(account_id)
    end)

    RPSTACK_LOG.info("permissions", "rpstack-permissions ready")
  end)
end)