local RSGCore = exports['rsg-core']:GetCoreObject()

-- self-migrating: don't depend on the SQL file having been run by hand
MySQL.query([[
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])

-- covers installs from before the `severity` column existed
MySQL.query("ALTER TABLE `admin_player_history` ADD COLUMN IF NOT EXISTS `severity` VARCHAR(20) DEFAULT NULL")

-- global (not local) so server.lua's kick/ban/warn handlers can call into it without a require system
function LogPlayerHistory(citizenid, action, reason, adminName, durationSeconds, severity)
    if not citizenid then return end
    MySQL.insert('INSERT INTO admin_player_history (citizenid, action, reason, admin_name, duration_seconds, severity) VALUES (?, ?, ?, ?, ?, ?)', {
        citizenid, action, reason, adminName, durationSeconds, severity,
    })
end

-- no persisted per-citizen role table exists in RSGCore (permissions are ACE-only), so this
-- checks the server's configured permission levels in priority order and falls back to 'user'
function GetPlayerRole(source)
    for _, level in ipairs(RSGCore.Config.Server.Permissions) do
        if IsPlayerAceAllowed(source, level) then
            return level
        end
    end
    return 'user'
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getplayerhistory', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['playerinfo']) or IsPlayerAceAllowed(src, 'god')) then
        cb(nil)
        return
    end

    MySQL.query('SELECT * FROM admin_player_history WHERE citizenid = ? ORDER BY created_at DESC LIMIT 50', { data.citizenid }, function(rows)
        cb(rows or {})
    end)
end)

-- only Owner ('god') and Head Admin may erase punishment history — every
-- other role is rejected here too, independent of the frontend hiding the button
function CanManageHistory(src)
    local role = GetPlayerRole(src)
    return role == 'god' or role == 'headadmin' or IsPlayerAceAllowed(src, 'god')
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:deletehistoryentry', function(source, cb, data)
    local src = source
    if not CanManageHistory(src) then
        cb({ success = false })
        return
    end

    MySQL.single('SELECT * FROM admin_player_history WHERE id = ?', { data.id }, function(entry)
        if not entry then
            cb({ success = false })
            return
        end

        MySQL.update('DELETE FROM admin_player_history WHERE id = ?', { data.id }, function(affected)
            if affected > 0 then
                LogAdminAction('admin_action', 'high', src, 'Deleted punishment history entry #' .. tostring(data.id),
                    entry.action .. ': ' .. (entry.reason or 'no reason'), nil)
            end
            cb({ success = affected > 0 })
        end)
    end)
end)
