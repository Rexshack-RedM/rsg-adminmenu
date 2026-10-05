local RSGCore = exports['rsg-core']:GetCoreObject()

-- self-migrating: don't depend on the SQL file having been run by hand
MySQL.query([[
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])

local function IsWhitelistAdmin(src)
    return RSGCore.Functions.HasPermission(src, permissions['whitelist']) or IsPlayerAceAllowed(src, 'god')
end

-----------------------------------------------------------------------
-- list (status is computed here: an active row past its expiry reads as expired)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getwhitelist', function(source, cb)
    local src = source
    if not IsWhitelistAdmin(src) then
        cb(nil)
        return
    end

    MySQL.query('SELECT * FROM admin_whitelist ORDER BY created_at DESC', {}, function(rows)
        local now = os.time()
        for _, row in ipairs(rows or {}) do
            if row.status == 'active' and row.expires_at then
                local expiresAt = type(row.expires_at) == 'number' and row.expires_at or nil
                if not expiresAt then
                    local year, month, day, hour, min, sec = tostring(row.expires_at):match("(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)")
                    if year then
                        expiresAt = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec) })
                    end
                end
                if expiresAt and expiresAt < now then
                    row.status = 'expired'
                end
            end
        end
        cb(rows)
    end)
end)

-----------------------------------------------------------------------
-- add / re-add an entry
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:addwhitelist', function(source, cb, data)
    local src = source
    if not IsWhitelistAdmin(src) then
        cb({ success = false, message = locale('sv_not_allowed') })
        return
    end

    local admin = RSGCore.Functions.GetPlayer(src)
    local adminName = admin.PlayerData.charinfo.firstname .. ' ' .. admin.PlayerData.charinfo.lastname

    local expiresAt = nil
    if data.expiresInDays and tonumber(data.expiresInDays) and tonumber(data.expiresInDays) > 0 then
        expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (tonumber(data.expiresInDays) * 86400))
    end

    MySQL.insert([[
        INSERT INTO admin_whitelist (citizenid, player_name, account_name, status, reason, added_by_name, expires_at)
        VALUES (?, ?, ?, 'active', ?, ?, ?)
        ON DUPLICATE KEY UPDATE status = 'active', player_name = ?, account_name = ?, reason = ?, added_by_name = ?, expires_at = ?
    ]], {
        data.citizenid, data.playerName, data.accountName, data.reason, adminName, expiresAt,
        data.playerName, data.accountName, data.reason, adminName, expiresAt,
    }, function()
        LogAdminAction('admin_action', 'medium', src, locale('sv_log_added_player_to_whitelist'), data.reason, data.playerName)
        cb({ success = true })
    end)
end)

-----------------------------------------------------------------------
-- change status (suspend / reactivate)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:setwhiteliststatus', function(source, cb, data)
    local src = source
    if not IsWhitelistAdmin(src) then
        cb({ success = false })
        return
    end

    MySQL.update('UPDATE admin_whitelist SET status = ? WHERE id = ?', { data.status, data.id }, function(affected)
        local success = affected > 0
        if success then
            LogAdminAction('admin_action', 'medium', src, locale('sv_log_changed_whitelist_status'), locale('sv_log_new_status', tostring(data.status)), nil)
        end
        cb({ success = success })
    end)
end)

-----------------------------------------------------------------------
-- remove
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:removewhitelist', function(source, cb, data)
    local src = source
    if not IsWhitelistAdmin(src) then
        cb({ success = false })
        return
    end

    MySQL.update('DELETE FROM admin_whitelist WHERE id = ?', { data.id }, function(affected)
        local success = affected > 0
        if success then
            LogAdminAction('admin_action', 'medium', src, locale('sv_log_removed_player_from_whitelist'), nil, nil)
        end
        cb({ success = success })
    end)
end)
