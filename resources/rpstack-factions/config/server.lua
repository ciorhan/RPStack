-- rpstack-factions/config/server.lua

RPSTACK_FACTIONS_CONFIG = {

  -- Maximum number of factions a single character can belong to simultaneously.
  -- 3 = gang + guild + political affiliation, without diluting faction meaning.
  max_factions_per_character = 3,

  -- Maximum tag length (short display identifier, e.g. "LAW", "MRC")
  tag_max_length = 8,
  tag_min_length = 2,

  -- Faction name limits
  name_min_length = 3,
  name_max_length = 64,

  -- Treasury: maximum single withdrawal per operation (0 = unlimited)
  treasury_max_withdraw = 0,

  -- Treasury: maximum single deposit per operation (0 = unlimited)
  treasury_max_deposit = 0,

  -- Default rank ladders seeded on faction creation.
  -- Each faction type gets its own culturally fitting rank names.
  -- level: higher = more authority. Founder receives the highest level rank.
  -- Permissions follow least-privilege: only top ranks get destructive perms.
  default_ranks = {

    gang = {
      { name = "Prospect",    level = 0, can_recruit = false, can_kick = false, can_deposit = true,  can_withdraw = false, can_promote = false, can_disband = false, can_declare = false },
      { name = "Soldier",     level = 1, can_recruit = true,  can_kick = false, can_deposit = true,  can_withdraw = false, can_promote = false, can_disband = false, can_declare = false },
      { name = "Lieutenant",  level = 2, can_recruit = true,  can_kick = true,  can_deposit = true,  can_withdraw = true,  can_promote = true,  can_disband = false, can_declare = false },
      { name = "Boss",        level = 3, can_recruit = true,  can_kick = true,  can_deposit = true,  can_withdraw = true,  can_promote = true,  can_disband = true,  can_declare = true  },
    },

    guild = {
      { name = "Apprentice",  level = 0, can_recruit = false, can_kick = false, can_deposit = true,  can_withdraw = false, can_promote = false, can_disband = false, can_declare = false },
      { name = "Journeyman",  level = 1, can_recruit = true,  can_kick = false, can_deposit = true,  can_withdraw = false, can_promote = false, can_disband = false, can_declare = false },
      { name = "Master",      level = 2, can_recruit = true,  can_kick = true,  can_deposit = true,  can_withdraw = true,  can_promote = true,  can_disband = false, can_declare = false },
      { name = "Guildmaster", level = 3, can_recruit = true,  can_kick = true,  can_deposit = true,  can_withdraw = true,  can_promote = true,  can_disband = true,  can_declare = true  },
    },

    political = {
      { name = "Supporter",   level = 0, can_recruit = false, can_kick = false, can_deposit = true,  can_withdraw = false, can_promote = false, can_disband = false, can_declare = false },
      { name = "Member",      level = 1, can_recruit = true,  can_kick = false, can_deposit = true,  can_withdraw = false, can_promote = false, can_disband = false, can_declare = false },
      { name = "Officer",     level = 2, can_recruit = true,  can_kick = true,  can_deposit = true,  can_withdraw = true,  can_promote = true,  can_disband = false, can_declare = false },
      { name = "Chair",       level = 3, can_recruit = true,  can_kick = true,  can_deposit = true,  can_withdraw = true,  can_promote = true,  can_disband = true,  can_declare = true  },
    },

    law = {
      { name = "Civilian",    level = 0, can_recruit = false, can_kick = false, can_deposit = true,  can_withdraw = false, can_promote = false, can_disband = false, can_declare = false },
      { name = "Deputy",      level = 1, can_recruit = true,  can_kick = false, can_deposit = true,  can_withdraw = false, can_promote = false, can_disband = false, can_declare = false },
      { name = "Marshal",     level = 2, can_recruit = true,  can_kick = true,  can_deposit = true,  can_withdraw = true,  can_promote = true,  can_disband = false, can_declare = false },
      { name = "Sheriff",     level = 3, can_recruit = true,  can_kick = true,  can_deposit = true,  can_withdraw = true,  can_promote = true,  can_disband = true,  can_declare = true  },
    },
  },
}