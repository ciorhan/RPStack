exports['rpstack-persistence']:registerMigration(
  'economy_001_create_economy_accounts',
  "CREATE TABLE IF NOT EXISTS `rpstack_economy_accounts` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `char_id` INT UNSIGNED NOT NULL, `cash` INT UNSIGNED NOT NULL DEFAULT 0, `bank` INT UNSIGNED NOT NULL DEFAULT 0, `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP, `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE KEY `uq_char_id` (`char_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
)

exports['rpstack-persistence']:registerMigration(
  'economy_002_create_transactions',
  "CREATE TABLE IF NOT EXISTS `rpstack_economy_transactions` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `char_id` INT UNSIGNED NOT NULL, `account` ENUM('cash','bank') NOT NULL, `amount` INT NOT NULL, `reason` VARCHAR(128) NOT NULL, `balance_after` INT UNSIGNED NOT NULL, `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), INDEX `idx_char_id` (`char_id`), INDEX `idx_created_at` (`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
)

AddEventHandler('rpstack:persistence:ready', function()
  CreateThread(function()
    Wait(0)
    RPSTACK_LOG.info("economy", "rpstack-economy starting")

    AddEventHandler('rpstack:identity:characterCreated', function(char_id)
      RPSTACK_ECONOMY_REPO.findByCharacter(char_id, function(existing)
        if existing then return end

        RPSTACK_ECONOMY_REPO.create(
          char_id,
          RPSTACK_ECONOMY_CONFIG.startingCash,
          RPSTACK_ECONOMY_CONFIG.startingBank,
          function(id)
            if not id then
              RPSTACK_LOG.error("economy", "failed to create economy account", { char_id = char_id })
              return
            end
            RPSTACK_LOG.info("economy", "economy account created", {
              char_id = char_id,
              cash    = RPSTACK_ECONOMY_CONFIG.startingCash,
              bank    = RPSTACK_ECONOMY_CONFIG.startingBank,
            })
          end
        )
      end)
    end)

    RPSTACK_LOG.info("economy", "rpstack-economy ready")
  end)
end)