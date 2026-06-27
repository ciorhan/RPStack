exports['rpstack-persistence']:registerMigration(
  'economy_001_create_economy_accounts',
  "CREATE TABLE IF NOT EXISTS `rpstack_economy_accounts` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `char_id` INT UNSIGNED NOT NULL, `cash` INT UNSIGNED NOT NULL DEFAULT 0, `bank` INT UNSIGNED NOT NULL DEFAULT 0, `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP, `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE KEY `uq_char_id` (`char_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
)

exports['rpstack-persistence']:registerMigration(
  'economy_002_create_transactions',
  "CREATE TABLE IF NOT EXISTS `rpstack_economy_transactions` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `char_id` INT UNSIGNED NOT NULL, `account` ENUM('cash','bank') NOT NULL, `amount` INT NOT NULL, `reason` VARCHAR(128) NOT NULL, `balance_after` INT UNSIGNED NOT NULL, `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), INDEX `idx_char_id` (`char_id`), INDEX `idx_created_at` (`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
)

exports['rpstack-persistence']:registerMigration(
  'economy_003_add_owner_type',
  "ALTER TABLE `rpstack_economy_accounts` MODIFY COLUMN `char_id` INT UNSIGNED NULL, ADD COLUMN IF NOT EXISTS `owner_type` VARCHAR(16) NOT NULL DEFAULT 'character' AFTER `char_id`, ADD COLUMN IF NOT EXISTS `owner_id` INT UNSIGNED NULL AFTER `owner_type`, ADD INDEX IF NOT EXISTS `idx_owner` (`owner_type`, `owner_id`)"
)

exports['rpstack-persistence']:registerMigration(
  'economy_004_backfill_owner_id',
  "UPDATE `rpstack_economy_accounts` SET `owner_id` = `char_id` WHERE `owner_type` = 'character' AND `owner_id` IS NULL AND `char_id` IS NOT NULL"
)

exports['rpstack-persistence']:registerMigration(
  'economy_005_complete_owner_accounts',
  "ALTER TABLE `rpstack_economy_accounts` ADD COLUMN IF NOT EXISTS `account_type` VARCHAR(16) NOT NULL DEFAULT 'default' AFTER `owner_id`, ADD UNIQUE INDEX IF NOT EXISTS `uq_owner_account` (`owner_type`, `owner_id`, `account_type`)"
)

exports['rpstack-persistence']:registerMigration(
  'economy_006_add_transaction_owners',
  "ALTER TABLE `rpstack_economy_transactions` MODIFY COLUMN `char_id` INT UNSIGNED NULL, ADD COLUMN IF NOT EXISTS `owner_type` VARCHAR(16) NOT NULL DEFAULT 'character' AFTER `char_id`, ADD COLUMN IF NOT EXISTS `owner_id` INT UNSIGNED NULL AFTER `owner_type`, ADD COLUMN IF NOT EXISTS `account_type` VARCHAR(16) NOT NULL DEFAULT 'default' AFTER `owner_id`, ADD INDEX IF NOT EXISTS `idx_transaction_owner` (`owner_type`, `owner_id`, `account_type`)"
)

exports['rpstack-persistence']:registerMigration(
  'economy_007_backfill_transaction_owners',
  "UPDATE `rpstack_economy_transactions` SET `owner_id` = `char_id` WHERE `owner_type` = 'character' AND `owner_id` IS NULL AND `char_id` IS NOT NULL"
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
              cash = RPSTACK_ECONOMY_CONFIG.startingCash,
              bank = RPSTACK_ECONOMY_CONFIG.startingBank,
            })
          end
        )
      end)
    end)

    RPSTACK_LOG.info("economy", "rpstack-economy ready")
  end)
end)
