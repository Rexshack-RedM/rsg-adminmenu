local RSGCore = exports['rsg-core']:GetCoreObject()

-- global so server.lua's kick/ban/warn handlers can call into it
function LogPlayerHistory(citizenid, action, reason, adminName, durationSeconds, severity)
    if not citizenid then return end
    MySQL.insert('INSERT INTO admin_player_history (citizenid, action, reason, admin_name, duration_seconds, severity) VALUES (?, ?, ?, ?, ?, ?)', {
        citizenid, action, reason, adminName, durationSeconds, severity,
    })
end

-- RSGCore permissions are ACE-only, so this scans the configured levels in
-- priority order and falls back to 'user'
function GetPlayerRole(source)
    for _, level in ipairs(RSGCore.Config.Server.Permissions) do
        if IsPlayerAceAllowed(source, level) then
            return level
        end
    end
    return 'user'
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getplayerhistory', function(source, cb, data)
    if not HasAdminPermission(source, 'playerinfo') then return cb(nil) end
    local citizenid = type(data) == 'table' and data.citizenid or nil
    if type(citizenid) ~= 'string' then return cb({}) end

    MySQL.query('SELECT * FROM admin_player_history WHERE citizenid = ? ORDER BY created_at DESC LIMIT 50', { citizenid }, function(rows)
        cb(rows or {})
    end)
end)

-- only Owner ('god') and Head Admin may erase punishment history
function CanManageHistory(src)
    local role = GetPlayerRole(src)
    return role == 'god' or role == 'headadmin' or IsPlayerAceAllowed(src, 'god')
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:deletehistoryentry', function(source, cb, data)
    local src = source
    local id = tonumber(type(data) == 'table' and data.id)
    if not CanManageHistory(src) or not id then return cb({ success = false }) end

    MySQL.single('SELECT * FROM admin_player_history WHERE id = ?', { id }, function(entry)
        if not entry then return cb({ success = false }) end

        MySQL.update('DELETE FROM admin_player_history WHERE id = ?', { id }, function(affected)
            local success = (affected or 0) > 0
            if success then
                LogAdminAction('admin_action', 'high', src, locale('sv_log_deleted_history', tostring(id)),
                    entry.action .. ': ' .. (entry.reason or locale('sv_no_reason')), nil)
            end
            cb({ success = success })
        end)
    end)
end)
