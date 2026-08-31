-- rsg-adminmenu: full install SQL
--
-- Every table below is also created automatically the first time the
-- resource starts (self-migrating schema: every CREATE TABLE across the
-- server/*.lua files uses IF NOT EXISTS), so running this file is optional.
-- It's provided for admins who prefer to set the schema up explicitly
-- before first start, review it, or run it as part of a scripted deploy.
-- Safe to run more than once, everything here is IF NOT EXISTS.
--
-- The one exception: `admin_reports` and its two related tables are NOT
-- self-migrated (existing installs may already have their own copy with
-- extra columns), so this file is the actual source of truth for those.

-- ============================================================
-- Admins & permissions
-- ============================================================

CREATE TABLE IF NOT EXISTS `admin_roles` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `license` VARCHAR(100) DEFAULT NULL,
  `discord` VARCHAR(50) DEFAULT NULL,
  `name` VARCHAR(255) DEFAULT NULL,
  `role` VARCHAR(20) NOT NULL,
  `granted_by` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Logging
-- ============================================================

CREATE TABLE IF NOT EXISTS `admin_logs` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `category` VARCHAR(20) NOT NULL,
  `severity` VARCHAR(10) NOT NULL DEFAULT 'low',
  `admin_citizenid` VARCHAR(50) DEFAULT NULL,
  `admin_name` VARCHAR(255) DEFAULT NULL,
  `action` VARCHAR(255) NOT NULL,
  `details` VARCHAR(500) DEFAULT NULL,
  `target_name` VARCHAR(255) DEFAULT NULL,
  `ip` VARCHAR(50) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `category` (`category`),
  KEY `admin_citizenid` (`admin_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `admin_player_history` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `action` VARCHAR(20) NOT NULL,
  `reason` VARCHAR(255) DEFAULT NULL,
  `admin_name` VARCHAR(255) DEFAULT NULL,
  `duration_seconds` INT(11) DEFAULT NULL,
  `severity` VARCHAR(20) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Admin Chat
-- ============================================================

CREATE TABLE IF NOT EXISTS `admin_chat_messages` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `sender_citizenid` VARCHAR(50) DEFAULT NULL,
  `sender_name` VARCHAR(255) NOT NULL,
  `sender_role` VARCHAR(20) DEFAULT NULL,
  `sender_discord_name` VARCHAR(255) DEFAULT NULL,
  `sender_discord_avatar_url` VARCHAR(500) DEFAULT NULL,
  `message` VARCHAR(500) NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Reports (NOT self-migrated, this file is the real source of truth)
-- ============================================================

CREATE TABLE IF NOT EXISTS `admin_reports` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `report_type` VARCHAR(50) NOT NULL,
  `severity` VARCHAR(20) DEFAULT 'medium',
  `reporter_id` INT(11) NOT NULL,
  `reporter_name` VARCHAR(255) NOT NULL,
  `reporter_license` VARCHAR(255) NOT NULL,
  `reporter_steam` VARCHAR(50) DEFAULT NULL,
  `reporter_discord` VARCHAR(255) DEFAULT NULL,
  `reporter_coords` VARCHAR(255) NOT NULL,
  `reported_player_id` INT(11) DEFAULT NULL,
  `reported_player_name` VARCHAR(255) DEFAULT NULL,
  `reported_player_license` VARCHAR(255) DEFAULT NULL,
  `reported_player_discord` VARCHAR(255) DEFAULT NULL,
  `title` VARCHAR(255) NOT NULL,
  `description` TEXT NOT NULL,
  `image_url` VARCHAR(500) DEFAULT NULL,
  `status` VARCHAR(50) DEFAULT 'open',
  `assigned_admin_id` INT(11) DEFAULT NULL,
  `assigned_admin_name` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `admin_report_messages` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `report_id` INT(11) NOT NULL,
  `sender_type` VARCHAR(50) NOT NULL,
  `sender_id` INT(11) NOT NULL,
  `sender_name` VARCHAR(255) NOT NULL,
  `message` TEXT NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`report_id`) REFERENCES `admin_reports`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `admin_report_nearby_players` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `report_id` INT(11) NOT NULL,
  `player_id` INT(11) NOT NULL,
  `player_name` VARCHAR(255) NOT NULL,
  `player_license` VARCHAR(255) NOT NULL,
  `distance` FLOAT NOT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`report_id`) REFERENCES `admin_reports`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Whitelist & statistics
-- ============================================================

CREATE TABLE IF NOT EXISTS `admin_whitelist` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `player_name` VARCHAR(255) NOT NULL,
  `account_name` VARCHAR(255) DEFAULT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'active',
  `reason` VARCHAR(255) DEFAULT NULL,
  `added_by_name` VARCHAR(255) DEFAULT NULL,
  `expires_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `player_playtime` (
  `citizenid` VARCHAR(50) NOT NULL,
  `minutes` INT(11) NOT NULL DEFAULT 0,
  `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `admin_activity_log` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `sample_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `online_count` INT(11) NOT NULL DEFAULT 0,
  `total_money` DECIMAL(15,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- World tools (Teleports, Blips)
-- ============================================================

CREATE TABLE IF NOT EXISTS `adminmenu_teleports` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  `category` VARCHAR(30) NOT NULL DEFAULT 'special',
  `description` VARCHAR(255) DEFAULT NULL,
  `x` FLOAT NOT NULL,
  `y` FLOAT NOT NULL,
  `z` FLOAT NOT NULL,
  `heading` FLOAT NOT NULL DEFAULT 0,
  `created_by` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `adminmenu_blips` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  `sprite` VARCHAR(50) NOT NULL,
  `x` FLOAT NOT NULL,
  `y` FLOAT NOT NULL,
  `z` FLOAT NOT NULL,
  `scale` FLOAT NOT NULL DEFAULT 1,
  `created_by` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Master Actions (webhook settings, custom items)
-- ============================================================

CREATE TABLE IF NOT EXISTS `adminmenu_settings` (
  `setting_key` VARCHAR(64) NOT NULL,
  `setting_value` TEXT,
  PRIMARY KEY (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `adminmenu_custom_items` (
  `name` VARCHAR(64) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `description` VARCHAR(255) DEFAULT NULL,
  `weight` INT(11) NOT NULL DEFAULT 0,
  `type` VARCHAR(20) NOT NULL DEFAULT 'item',
  `image` VARCHAR(150) NOT NULL,
  `created_by` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
