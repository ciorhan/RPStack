-- rpstack-factions/server/main.lua
-- Migrations registered at top level so persistence picks them up before firing ready.

exports['rpstack-persistence']:registerMigration('factions_v1',
  "CREATE TABLE IF NOT EXISTS `rpstack_factions` (`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `name` VARCHAR(64) NOT NULL, `tag` VARCHAR(8) NOT NULL, `type` VARCHAR(32) NOT NULL, `description` TEXT, `is_active` TINYINT(1) NOT NULL DEFAULT 1, `created_at` BIGINT NOT NULL, `disbanded_at` BIGINT, UNIQUE KEY `uq_name` (`name`), UNIQUE KEY `uq_tag` (`tag`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4")

exports['rpstack-persistence']:registerMigration('factions_ranks_v1',
  "CREATE TABLE IF NOT EXISTS `rpstack_faction_ranks` (`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `faction_id` INT UNSIGNED NOT NULL, `name` VARCHAR(32) NOT NULL, `level` TINYINT UNSIGNED NOT NULL, `can_recruit` TINYINT(1) NOT NULL DEFAULT 0, `can_kick` TINYINT(1) NOT NULL DEFAULT 0, `can_deposit` TINYINT(1) NOT NULL DEFAULT 1, `can_withdraw` TINYINT(1) NOT NULL DEFAULT 0, `can_promote` TINYINT(1) NOT NULL DEFAULT 0, `can_disband` TINYINT(1) NOT NULL DEFAULT 0, `can_declare` TINYINT(1) NOT NULL DEFAULT 0, FOREIGN KEY (`faction_id`) REFERENCES `rpstack_factions`(`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4")

exports['rpstack-persistence']:registerMigration('factions_members_v1',
  "CREATE TABLE IF NOT EXISTS `rpstack_faction_members` (`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `faction_id` INT UNSIGNED NOT NULL, `character_id` INT UNSIGNED NOT NULL, `rank_id` INT UNSIGNED NOT NULL, `joined_at` BIGINT NOT NULL, UNIQUE KEY `uq_member` (`faction_id`, `character_id`), INDEX `idx_character` (`character_id`), FOREIGN KEY (`faction_id`) REFERENCES `rpstack_factions`(`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4")

exports['rpstack-persistence']:registerMigration('factions_relationships_v1',
  "CREATE TABLE IF NOT EXISTS `rpstack_faction_relationships` (`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `faction_a_id` INT UNSIGNED NOT NULL, `faction_b_id` INT UNSIGNED NOT NULL, `status` VARCHAR(16) NOT NULL DEFAULT 'neutral', `declared_by` INT UNSIGNED, `declared_at` BIGINT NOT NULL, UNIQUE KEY `uq_pair` (`faction_a_id`, `faction_b_id`), FOREIGN KEY (`faction_a_id`) REFERENCES `rpstack_factions`(`id`), FOREIGN KEY (`faction_b_id`) REFERENCES `rpstack_factions`(`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4")

exports['rpstack-persistence']:registerMigration('factions_audit_log_v1',
  "CREATE TABLE IF NOT EXISTS `rpstack_faction_audit_log` (`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `faction_id` INT UNSIGNED NOT NULL, `actor_char_id` INT UNSIGNED NOT NULL, `action` VARCHAR(64) NOT NULL, `payload` TEXT, `created_at` BIGINT NOT NULL, INDEX `idx_faction_time` (`faction_id`, `created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4")

exports['rpstack-persistence']:registerMigration('factions_rank_levels_v2',
  "ALTER TABLE `rpstack_faction_ranks` ADD UNIQUE INDEX IF NOT EXISTS `uq_faction_rank_level` (`faction_id`, `level`)")

AddEventHandler('rpstack:persistence:ready', function()
  CreateThread(function()
    Wait(0)

    RPSTACK_LOG.info("factions", "starting")

    RPSTACK_FACTIONS_CACHE.hydrate(function()

      AddEventHandler('rpstack:identity:characterLoaded', function(data)
        if data and data.characterId then
          RPSTACK_FACTIONS_MEMBERSHIP.onCharacterLoaded(data.characterId)
        end
      end)

      AddEventHandler('rpstack:identity:characterUnloaded', function(data)
        if data and data.characterId then
          RPSTACK_FACTIONS_MEMBERSHIP.onCharacterUnloaded(data.characterId)
        end
      end)


      RPSTACK_LOG.info("factions", "ready", {
        factions = (function()
          local n = 0
          for _ in pairs(RPSTACK_FACTIONS_STATE.factions) do n = n + 1 end
          return n
        end)()
      })

      TriggerEvent(FACTION_EVENTS.READY)
    end)
  end)
end)