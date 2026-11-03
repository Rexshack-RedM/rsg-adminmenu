local RSGCore = exports['rsg-core']:GetCoreObject()

local CHAT_COOLDOWN = 1 -- seconds between messages from one admin
local lastMessage = {}

-----------------------------------------------------------------------
-- post a message — broadcast in realtime to every online admin
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:createadminchatmessage', function(source, cb, data)
    local src = source
    if not HasAdminPermission(src, 'adminmenu') then return cb({ success = false }) end

    local message = SanitizeText(type(data) == 'table' and data.message, 500)
    local Player = RSGCore.Functions.GetPlayer(src)
    local now = os.time()
    if not message or not Player or (lastMessage[src] and now - lastMessage[src] < CHAT_COOLDOWN) then
        return cb({ success = false })
    end
    lastMessage[src] = now

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
        for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
            if HasAdminPermission(playerId, 'adminmenu') then
                TriggerClientEvent('rsg-adminmenu:client:adminchatmessage', playerId, payload)
            end
        end
        cb({ success = true })
    end)
end)

-----------------------------------------------------------------------
-- recent history
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getadminchatmessages', function(source, cb)
    if not HasAdminPermission(source, 'adminmenu') then return cb({}) end

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

AddEventHandler('playerDropped', function()
    lastMessage[source] = nil
end)
