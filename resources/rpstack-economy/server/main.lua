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

-- Migration: economy_accounts owner_type extension
-- Registered by rpstack-economy on startup.
-- Adds generic owner_type + owner_id columns so any entity
-- (faction, town, railroad, etc.) can hold an economy account.
-- character_id becomes nullable; existing rows are backfilled.
--
-- This migration MUST run before rpstack-factions starts.
-- Dependency is enforced via server.cfg load order:
--   ensure rpstack-economy   (before)
--   ensure rpstack-factions  (after)

RPSTACK_ECONOMY_MIGRATIONS = RPSTACK_ECONOMY_MIGRATIONS or {}

table.insert(RPSTACK_ECONOMY_MIGRATIONS, {
  id  = "economy_accounts_owner_type_v1",
  up  = "ALTER TABLE economy_accounts MODIFY COLUMN character_id INT UNSIGNED NULL, ADD COLUMN IF NOT EXISTS owner_type VARCHAR(16) NOT NULL DEFAULT 'character' AFTER character_id, ADD COLUMN IF NOT EXISTS owner_id INT UNSIGNED NULL AFTER owner_type, ADD INDEX IF NOT EXISTS idx_owner (owner_type, owner_id)",
  -- Backfill: for all existing character rows, set owner_id = character_id
  post = "UPDATE economy_accounts SET owner_id = character_id WHERE owner_type = 'character' AND owner_id IS NULL AND character_id IS NOT NULL",
})