local RSGCore = exports['rsg-core']:GetCoreObject()

-- self-migrating: custom teleport locations and map blips added via the panel
MySQL.query([[
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])

MySQL.query([[
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])


RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getteleportlocations', function(source, cb)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['playerinfo']) or IsPlayerAceAllowed(src, 'god')) then
        cb({})
        return
    end
    MySQL.query('SELECT * FROM adminmenu_teleports ORDER BY name ASC', {}, function(rows)
        cb(rows or {})
    end)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:addteleportlocation', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['worldtools']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false })
        return
    end
    local Player = RSGCore.Functions.GetPlayer(src)
    local adminName = AdminDisplayName(src)
    MySQL.insert('INSERT INTO adminmenu_teleports (name, category, description, x, y, z, heading, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        data.name, data.category or 'special', data.description, data.x, data.y, data.z, data.heading or 0, adminName,
    }, function(insertId)
        LogAdminAction('admin_action', 'low', src, locale('sv_log_added_teleport', tostring(data.name)), nil, nil)
        cb({ success = insertId ~= nil, id = insertId })
    end)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:deleteteleportlocation', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['worldtools']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false })
        return
    end
    MySQL.update('DELETE FROM adminmenu_teleports WHERE id = ?', { data.id }, function(affected)
        cb({ success = affected > 0 })
    end)
end)


RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getblips', function(source, cb)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['playerinfo']) or IsPlayerAceAllowed(src, 'god')) then
        cb({})
        return
    end
    MySQL.query('SELECT * FROM adminmenu_blips ORDER BY name ASC', {}, function(rows)
        cb(rows or {})
    end)
end)

local function BroadcastBlips()
    MySQL.query('SELECT * FROM adminmenu_blips', {}, function(rows)
        for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
            if RSGCore.Functions.HasPermission(playerId, permissions['adminmenu']) then
                TriggerClientEvent('rsg-adminmenu:client:syncblips', playerId, rows or {})
            end
        end
    end)
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:addblip', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['worldtools']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false })
        return
    end
    local adminName = AdminDisplayName(src)
    MySQL.insert('INSERT INTO adminmenu_blips (name, sprite, x, y, z, scale, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        data.name, data.sprite, data.x, data.y, data.z, data.scale or 1, adminName,
    }, function(insertId)
        LogAdminAction('admin_action', 'low', src, locale('sv_log_added_blip', tostring(data.name)), nil, nil)
        BroadcastBlips()
        cb({ success = insertId ~= nil })
    end)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:updateblip', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['worldtools']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false })
        return
    end
    MySQL.update('UPDATE adminmenu_blips SET name = ?, sprite = ?, x = ?, y = ?, z = ?, scale = ? WHERE id = ?', {
        data.name, data.sprite, data.x, data.y, data.z, data.scale or 1, data.id,
    }, function(affected)
        BroadcastBlips()
        cb({ success = affected > 0 })
    end)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:deleteblip', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['worldtools']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false })
        return
    end
    MySQL.update('DELETE FROM adminmenu_blips WHERE id = ?', { data.id }, function(affected)
        BroadcastBlips()
        cb({ success = affected > 0 })
    end)
end)


AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    if RSGCore.Functions.HasPermission(src, permissions['adminmenu']) then
        MySQL.query('SELECT * FROM adminmenu_blips', {}, function(rows)
            TriggerClientEvent('rsg-adminmenu:client:syncblips', src, rows or {})
        end)
    end
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:spawnentity', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['worldtools']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false })
        return
    end
    local hash = data.hash and tostring(data.hash):gsub('%s+', '') or ''
    if hash == '' then
        cb({ success = false, message = locale('sv_hash_name_required') })
        return
    end
    TriggerClientEvent('rsg-adminmenu:client:spawnentity', src, data.entityType, hash)
    LogAdminAction('admin_action', 'low', src, locale('sv_log_spawned_entity'), data.entityType .. ': ' .. hash, nil)
    cb({ success = true })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:cleararea', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['worldtools']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false, message = locale('sv_no_permission') })
        return
    end
    local radius = tonumber(data and data.radius) or 25
    radius = math.max(5.0, math.min(100.0, radius + 0.0))
    TriggerClientEvent('rsg-adminmenu:client:cleararea', src, radius)
    LogAdminAction('admin_action', 'low', src, locale('sv_log_cleared_area'), locale('sv_log_radius', ('%.0f'):format(radius)), nil)
    cb({ success = true, radius = radius })
end)
