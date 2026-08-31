local RSGCore = exports['rsg-core']:GetCoreObject()

MySQL.query([[
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])
MySQL.query("ALTER TABLE admin_chat_messages ADD COLUMN IF NOT EXISTS sender_discord_name VARCHAR(255) DEFAULT NULL")
MySQL.query("ALTER TABLE admin_chat_messages ADD COLUMN IF NOT EXISTS sender_discord_avatar_url VARCHAR(500) DEFAULT NULL")

local function GetOnlineAdmins()
    local admins = {}
    for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
        if RSGCore.Functions.HasPermission(playerId, permissions['adminmenu']) then
            admins[#admins + 1] = playerId
        end
    end
    return admins
end

-----------------------------------------------------------------------
-- post a message — broadcast in realtime to every online admin
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:createadminchatmessage', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['adminmenu']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false })
        return
    end

    local message = data and data.message and data.message:sub(1, 500) or ''
    if message == '' then
        cb({ success = false })
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    local senderName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local senderRole = GetPlayerRole(src)
    local _, discordName, discordAvatarUrl = GetCachedDiscordIdentity(src)

    MySQL.insert('INSERT INTO admin_chat_messages (sender_citizenid, sender_name, sender_role, sender_discord_name, sender_discord_avatar_url, message) VALUES (?, ?, ?, ?, ?, ?)', {
        Player.PlayerData.citizenid, senderName, senderRole, discordName, discordAvatarUrl, message,
    }, function(insertId)
        local payload = {
            id = insertId,
            sender_citizenid = Player.PlayerData.citizenid,
            sender_name = senderName,
            sender_role = senderRole,
            sender_role_label = LabelForRole(senderRole),
            sender_discord_name = discordName,
            sender_discord_avatar_url = discordAvatarUrl,
            message = message,
            created_at = os.date('%Y-%m-%d %H:%M:%S'),
        }
        for _, adminId in ipairs(GetOnlineAdmins()) do
            TriggerClientEvent('rsg-adminmenu:client:adminchatmessage', adminId, payload)
        end
        cb({ success = true })
    end)
end)

-----------------------------------------------------------------------
-- recent history
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getadminchatmessages', function(source, cb)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['adminmenu']) or IsPlayerAceAllowed(src, 'god')) then
        cb({})
        return
    end

    MySQL.query('SELECT * FROM admin_chat_messages ORDER BY created_at DESC LIMIT 50', {}, function(rows)
        rows = rows or {}
        local ordered = {}
        for i = #rows, 1, -1 do
            local row = rows[i]
            row.sender_role_label = LabelForRole(row.sender_role)
            ordered[#ordered + 1] = row
        end
        cb(ordered)
    end)
end)
