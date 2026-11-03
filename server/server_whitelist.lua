local RSGCore = exports['rsg-core']:GetCoreObject()

local allowedStatuses = { active = true, suspended = true }

local function IsWhitelistAdmin(src)
    return HasAdminPermission(src, 'whitelist')
end

local function ParseTimestamp(value)
    if type(value) == 'number' then
        -- oxmysql returns TIMESTAMP columns as epoch milliseconds
        return value > 1e11 and math.floor(value / 1000) or value
    end
    local year, month, day, hour, min, sec = tostring(value or ''):match('(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)')
    if not year then return nil end
    return os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec) })
end

local function IsEntryActive(row, now)
    if not row or row.status ~= 'active' then return false end
    local expiresAt = row.expires_at and ParseTimestamp(row.expires_at)
    return not expiresAt or expiresAt >= now
end

-----------------------------------------------------------------------
-- optional enforcement: characters without an active entry are dropped
-- once loaded (staff are exempt). Off by default, see Config.Whitelist.
-----------------------------------------------------------------------
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if not (Config.Whitelist and Config.Whitelist.Enforce) then return end
    local src = Player.PlayerData.source
    if HasAdminPermission(src, 'adminmenu') then return end

    MySQL.single('SELECT status, expires_at FROM admin_whitelist WHERE citizenid = ?', { Player.PlayerData.citizenid }, function(row)
        if not IsEntryActive(row, os.time()) then
            DropPlayer(src, locale('sv_not_whitelisted'))
        end
    end)
end)

-----------------------------------------------------------------------
-- list (status is computed here: an active row past its expiry reads as expired)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getwhitelist', function(source, cb)
    if not IsWhitelistAdmin(source) then return cb(nil) end

    MySQL.query('SELECT * FROM admin_whitelist ORDER BY created_at DESC', {}, function(rows)
        local now = os.time()
        for _, row in ipairs(rows or {}) do
            if row.status == 'active' and not IsEntryActive(row, now) then
                row.status = 'expired'
            end
        end
        cb(rows or {})
    end)
end)

-----------------------------------------------------------------------
-- add / re-add an entry
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:addwhitelist', function(source, cb, data)
    local src = source
    if not IsWhitelistAdmin(src) then
        return cb({ success = false, message = locale('sv_not_allowed') })
    end
    data = type(data) == 'table' and data or {}

    local citizenid = SanitizeText(data.citizenid, 50)
    local playerName = SanitizeText(data.playerName, 255)
    if not citizenid or not playerName then
        return cb({ success = false, message = locale('sv_invalid_value') })
    end
    local accountName = SanitizeText(data.accountName, 255)
    local reason = SanitizeText(data.reason, 255)

    local admin = RSGCore.Functions.GetPlayer(src)
    local adminName = admin and (admin.PlayerData.charinfo.firstname .. ' ' .. admin.PlayerData.charinfo.lastname) or GetPlayerName(src)

    local days = tonumber(data.expiresInDays)
    local expiresAt = (days and days > 0) and os.date('%Y-%m-%d %H:%M:%S', os.time() + math.floor(days * 86400)) or nil

    MySQL.insert([[
        INSERT INTO admin_whitelist (citizenid, player_name, account_name, status, reason, added_by_name, expires_at)
        VALUES (?, ?, ?, 'active', ?, ?, ?)
        ON DUPLICATE KEY UPDATE status = 'active', player_name = VALUES(player_name), account_name = VALUES(account_name),
            reason = VALUES(reason), added_by_name = VALUES(added_by_name), expires_at = VALUES(expires_at)
    ]], { citizenid, playerName, accountName, reason, adminName, expiresAt }, function()
        LogAdminAction('admin_action', 'medium', src, locale('sv_log_added_player_to_whitelist'), reason, playerName)
        cb({ success = true })
    end)
end)

-----------------------------------------------------------------------
-- change status (suspend / reactivate)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:setwhiteliststatus', function(source, cb, data)
    local src = source
    data = type(data) == 'table' and data or {}
    local id = tonumber(data.id)
    if not IsWhitelistAdmin(src) or not id or not allowedStatuses[data.status] then return cb({ success = false }) end

    MySQL.update('UPDATE admin_whitelist SET status = ? WHERE id = ?', { data.status, id }, function(affected)
        local success = (affected or 0) > 0
        if success then
            LogAdminAction('admin_action', 'medium', src, locale('sv_log_changed_whitelist_status'), locale('sv_log_new_status', data.status), nil)
        end
        cb({ success = success })
    end)
end)

-----------------------------------------------------------------------
-- remove
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:removewhitelist', function(source, cb, data)
    local src = source
    local id = tonumber(type(data) == 'table' and data.id)
    if not IsWhitelistAdmin(src) or not id then return cb({ success = false }) end

    MySQL.update('DELETE FROM admin_whitelist WHERE id = ?', { id }, function(affected)
        local success = (affected or 0) > 0
        if success then
            LogAdminAction('admin_action', 'medium', src, locale('sv_log_removed_player_from_whitelist'), nil, nil)
        end
        cb({ success = success })
    end)
end)
