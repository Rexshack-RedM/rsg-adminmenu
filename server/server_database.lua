-----------------------------------------------------------------------
-- database setup: every table this resource uses, kept identical to
-- install.sql. Runs once on start when Config.AutoDatabase is true; other
-- files defer their startup queries through OnDatabaseReady().
-----------------------------------------------------------------------
local schema = {
    [[CREATE TABLE IF NOT EXISTS `admin_roles` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `admin_logs` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `admin_player_history` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `admin_chat_messages` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `sender_citizenid` VARCHAR(50) DEFAULT NULL,
        `sender_name` VARCHAR(255) NOT NULL,
        `sender_role` VARCHAR(20) DEFAULT NULL,
        `sender_discord_name` VARCHAR(255) DEFAULT NULL,
        `sender_discord_avatar_url` VARCHAR(500) DEFAULT NULL,
        `message` VARCHAR(500) NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `admin_reports` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `admin_report_messages` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `report_id` INT(11) NOT NULL,
        `sender_type` VARCHAR(50) NOT NULL,
        `sender_id` INT(11) NOT NULL,
        `sender_name` VARCHAR(255) NOT NULL,
        `message` TEXT NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        FOREIGN KEY (`report_id`) REFERENCES `admin_reports`(`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `admin_report_nearby_players` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `report_id` INT(11) NOT NULL,
        `player_id` INT(11) NOT NULL,
        `player_name` VARCHAR(255) NOT NULL,
        `player_license` VARCHAR(255) NOT NULL,
        `distance` FLOAT NOT NULL,
        PRIMARY KEY (`id`),
        FOREIGN KEY (`report_id`) REFERENCES `admin_reports`(`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `admin_whitelist` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `player_playtime` (
        `citizenid` VARCHAR(50) NOT NULL,
        `minutes` INT(11) NOT NULL DEFAULT 0,
        `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `admin_activity_log` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `sample_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `online_count` INT(11) NOT NULL DEFAULT 0,
        `total_money` DECIMAL(15,2) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `adminmenu_teleports` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `adminmenu_blips` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `adminmenu_settings` (
        `setting_key` VARCHAR(64) NOT NULL,
        `setting_value` TEXT,
        PRIMARY KEY (`setting_key`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `adminmenu_custom_items` (
        `name` VARCHAR(64) NOT NULL,
        `label` VARCHAR(100) NOT NULL,
        `description` VARCHAR(255) DEFAULT NULL,
        `weight` INT(11) NOT NULL DEFAULT 0,
        `type` VARCHAR(20) NOT NULL DEFAULT 'item',
        `image` VARCHAR(150) NOT NULL,
        `created_by` VARCHAR(255) DEFAULT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

-- columns added after the first release: { table, column, definition }
local addedColumns = {
    { 'admin_reports', 'severity', "VARCHAR(20) DEFAULT 'medium'" },
    { 'admin_reports', 'reporter_steam', 'VARCHAR(50) DEFAULT NULL' },
    { 'admin_player_history', 'severity', 'VARCHAR(20) DEFAULT NULL' },
    { 'admin_chat_messages', 'sender_discord_name', 'VARCHAR(255) DEFAULT NULL' },
    { 'admin_chat_messages', 'sender_discord_avatar_url', 'VARCHAR(500) DEFAULT NULL' },
    { 'admin_activity_log', 'total_money', 'DECIMAL(15,2) NOT NULL DEFAULT 0' },
}

local function ensureDatabase()
    local ok, err = pcall(function()
        for _, query in ipairs(schema) do
            MySQL.query.await(query)
        end
        for _, col in ipairs(addedColumns) do
            local exists = MySQL.scalar.await(
                'SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
                { col[1], col[2] })
            if (tonumber(exists) or 0) == 0 then
                MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(col[1], col[2], col[3]))
            end
        end
    end)
    if not ok then
        print(('^1[%s] database setup failed: %s^7'):format(GetCurrentResourceName(), tostring(err)))
        return false
    end
    print(('^2[%s] database tables ready^7'):format(GetCurrentResourceName()))
    return true
end

local dbReady = false
local readyQueue = {}

-- global: lets the other server files hold their startup queries until the
-- tables are guaranteed to exist
function OnDatabaseReady(fn)
    if dbReady then
        fn()
    else
        readyQueue[#readyQueue + 1] = fn
    end
end

CreateThread(function()
    if Config.AutoDatabase and not ensureDatabase() then return end
    dbReady = true
    for _, fn in ipairs(readyQueue) do
        fn()
    end
    readyQueue = nil
end)
