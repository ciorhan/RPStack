-- Register migrations before persistence runs them
exports['rpstack-persistence']['rpstack:persistence:registerMigration'](
  'rpstack-identity',
  '001_create_accounts',
  [[
    CREATE TABLE IF NOT EXISTS `rpstack_accounts` (
      `id`                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `primary_identifier` VARCHAR(64)  NOT NULL,
      `name`               VARCHAR(64)  NOT NULL,
      `created_at`         DATETIME     DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uq_identifier` (`primary_identifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]]
)

exports['rpstack-persistence']['rpstack:persistence:registerMigration'](
  'rpstack-identity',
  '002_create_characters',
  [[
    CREATE TABLE IF NOT EXISTS `rpstack_characters` (
      `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `account_id` INT UNSIGNED NOT NULL,
      `first_name` VARCHAR(24)  NOT NULL,
      `last_name`  VARCHAR(24)  NOT NULL,
      `created_at` DATETIME     DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (`id`),
      INDEX `idx_account_id` (`account_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]]
)

-- Wait for persistence to be ready before registering handlers
AddEventHandler('rpstack:persistence:ready', function()
  RPSTACK_LOG.info("identity", "rpstack-identity starting")

  AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    deferrals.defer()

    RPSTACK_IDENTITY_SESSION.onPlayerJoining(src, function(session, err)
      if not session then
        deferrals.done("Connection error. Please try again.")
        return
      end
      deferrals.done()
    end)
  end)

  AddEventHandler('playerDropped', function(reason)
    local src = source
    RPSTACK_IDENTITY_SESSION.onPlayerDropped(src, reason)
  end)

  RPSTACK_LOG.info("identity", "rpstack-identity ready")
end)