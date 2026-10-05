local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- tiered by role: 'helper' = every staff role, 'mod' = moderator and above,
-- 'admin' = admin and above, 'headadmin' = only Head Admin/Owner (Owner also
-- holds 'headadmin' via server.cfg inheritance, so 'headadmin' alone covers both)
permissions = {
    ['adminmenu'] = 'helper',
    ['revive'] = 'helper',
    ['inventory'] = 'helper',
    ['kick'] = 'mod',
    ['ban'] = 'admin',
    ['goto'] = 'helper',
    ['bring'] = 'helper',
    ['freeze'] = 'helper',
    ['spectate'] = 'helper',
    ['wildattack'] = 'mod',
    ['setonfire'] = 'mod',
    ['giveitem'] = 'helper',
    ['playerinfo'] = 'helper',
    ['givemoney'] = 'admin',
    ['whitelist'] = 'mod',
    ['heal'] = 'helper',
    ['kill'] = 'helper',
    ['ragdoll'] = 'mod',
    ['lightning'] = 'mod',
    ['toheaven'] = 'mod',
    ['drainstamina'] = 'mod',
    ['handcuff'] = 'mod',
    ['drunk'] = 'mod',
    ['setpermission'] = 'headadmin',
    ['setjob'] = 'helper',
    ['setcharfield'] = 'helper',
    ['xp'] = 'helper',
    ['clearweapons'] = 'admin',
    ['clearitems'] = 'admin',
    ['warn'] = 'mod',
    ['jumpscare'] = 'mod',
    ['horsebuck'] = 'mod',
    ['haunted'] = 'mod',
    ['everyoneattack'] = 'mod',
    ['worldtools'] = 'mod', -- Live Map, Teleports, Blips, Spawner mutations (Coords/self-teleport is helper via 'playerinfo'/'goto')
    -- 'headadmin' alone would lock this out on RSGCore's actual shipped server.cfg
    -- template — it only ever wires up god/developer/admin/mod/helper groups, no
    -- headadmin section at all, so 'god' is the real top tier in practice. Matches
    -- the same {'headadmin','developer'} check 'fullAccess' already does elsewhere.
    ['serversettings'] = { 'god', 'headadmin', 'developer' }, -- server actions (close/kick-all/refresh/announce), time/weather/wind/timescale, resource management, Master Actions
}

-----------------------------------------------------------------------
-- get players function
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getplayers', function(source, cb)
    local src = source
    local players = {}
    for k, v in pairs(RSGCore.Functions.GetPlayers()) do
        local target = GetPlayerPed(v)
        local ped = RSGCore.Functions.GetPlayer(v)
        players[#players + 1] = {
            name = ped.PlayerData.charinfo.firstname ..
            ' ' .. ped.PlayerData.charinfo.lastname .. ' | (' .. GetPlayerName(v) .. ')',
            id = v,
            coords = GetEntityCoords(target),
            citizenid = ped.PlayerData.citizenid,
            sources = GetPlayerPed(ped.PlayerData.source),
            sourceplayer = ped.PlayerData.source
        }
    end

    table.sort(players, function(a, b)
        return a.id < b.id
    end)

    cb(players)
end)

-----------------------------------------------------------------------
-- ban player function
----------------------------------------------------------------------
local function BanPlayer(src)
    MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {
            GetPlayerName(src),
            RSGCore.Functions.GetIdentifier(src, 'license'),
            RSGCore.Functions.GetIdentifier(src, 'discord'),
            RSGCore.Functions.GetIdentifier(src, 'ip'),
            locale('sv_system_banned_you'),
            2524608000,
            'rsg-adminmenu'
        })
    TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_a'), 'red',
        string.format(locale('sv_b'), GetPlayerName(src), 'rsg-adminmenu', locale('sv_c')), true)
    DropPlayer(src, locale('sv_105'))
end

-----------------------------------------------------------------------
-- resolve a discord:<id> identifier into the account's real Discord name
-----------------------------------------------------------------------
local discordNameCache = {}

-- synchronous read for list/table rendering — only returns something once
-- ResolveDiscordName has warmed the cache for this id (on join, or on-demand elsewhere)
-- global (not local) so server_stats.lua's leaderboard query can read it too
function GetCachedDiscordIdentity(source)
    local discordId = RSGCore.Functions.GetIdentifier(source, 'discord')
    if not discordId then return nil, nil, nil end
    discordId = discordId:gsub('discord:', '')
    local cached = discordNameCache[discordId]
    if not cached then return discordId, nil, nil end
    return discordId, cached.name, cached.avatarUrl
end

-- what should show as "By: ..." for an acting admin — prefer their Discord
-- name (matches how they're identified everywhere else in the panel), falling
-- back to their Rockstar account name only if Discord isn't linked/cached
function AdminDisplayName(source)
    local _, discordName = GetCachedDiscordIdentity(source)
    return discordName or GetPlayerName(source)
end

-- global (not local) so server_reports.lua can resolve a reporter's discord
-- name/avatar for the report detail view without duplicating this logic
function ResolveDiscordName(discordId, cb)
    if not discordId or discordId == '' then
        cb(nil, nil)
        return
    end

    if discordNameCache[discordId] then
        local cached = discordNameCache[discordId]
        cb(cached.name, cached.avatarUrl)
        return
    end

    local token = Config.DiscordBot and Config.DiscordBot.Token
    if not token or token == '' or token == 'YOUR_DISCORD_BOT_TOKEN_HERE' then
        cb(nil, nil)
        return
    end

    PerformHttpRequest('https://discord.com/api/v10/users/' .. discordId, function(statusCode, resultData)
        if statusCode ~= 200 or not resultData then
            cb(nil, nil)
            return
        end

        local ok, decoded = pcall(json.decode, resultData)
        if not ok or not decoded then
            cb(nil, nil)
            return
        end

        local name = decoded.global_name or decoded.username
        local avatarUrl = nil
        if decoded.avatar then
            local ext = decoded.avatar:sub(1, 2) == 'a_' and 'gif' or 'png'
            avatarUrl = 'https://cdn.discordapp.com/avatars/' .. discordId .. '/' .. decoded.avatar .. '.' .. ext .. '?size=128'
        end

        if name then
            discordNameCache[discordId] = { name = name, avatarUrl = avatarUrl }
        end
        cb(name, avatarUrl)
    end, 'GET', '', {
        ['Authorization'] = 'Bot ' .. token,
        ['Content-Type'] = 'application/json',
    })
end

-----------------------------------------------------------------------
-- warm the discord name/avatar cache on connect so the players list and
-- manage modal can read it synchronously instead of blocking on an HTTP call.
--
-- Queued and throttled rather than fired immediately for every join: on a
-- busy server, a burst of (re)connects (right after a restart, most
-- obviously) would otherwise fire one Discord API request per player all at
-- once, risking a 429 rate-limit response that could affect every other
-- lookup sharing this bot token. This drains at ~6/s instead, which any
-- realistic join burst clears in a few seconds without ever bursting Discord.
-----------------------------------------------------------------------
local discordWarmQueue = {}
local discordWarmQueueRunning = false

local function ProcessDiscordWarmQueue()
    if discordWarmQueueRunning then return end
    discordWarmQueueRunning = true
    CreateThread(function()
        while #discordWarmQueue > 0 do
            local discordId = table.remove(discordWarmQueue, 1)
            if not discordNameCache[discordId] then
                ResolveDiscordName(discordId, function() end)
            end
            Wait(150)
        end
        discordWarmQueueRunning = false
    end)
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    -- no bot token configured means ResolveDiscordName would no-op anyway
    -- (checked internally), so skip queueing entirely rather than pay even
    -- the cheap cost of a table insert for every join on servers that
    -- haven't set this up
    local token = Config.DiscordBot and Config.DiscordBot.Token
    if not token or token == '' or token == 'YOUR_DISCORD_BOT_TOKEN_HERE' then return end

    local discordId = RSGCore.Functions.GetIdentifier(Player.PlayerData.source, 'discord')
    if discordId then
        discordId = discordId:gsub('discord:', '')
        discordWarmQueue[#discordWarmQueue + 1] = discordId
        ProcessDiscordWarmQueue()
    end
end)

-----------------------------------------------------------------------
-- the bot's own avatar, used as the sidebar logo
-----------------------------------------------------------------------
local botIdentityCache = nil

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getbotlogo', function(source, cb)
    if botIdentityCache ~= nil then
        cb(botIdentityCache)
        return
    end

    local token = Config.DiscordBot and Config.DiscordBot.Token
    if not token or token == '' or token == 'YOUR_DISCORD_BOT_TOKEN_HERE' then
        cb({})
        return
    end

    PerformHttpRequest('https://discord.com/api/v10/users/@me', function(statusCode, resultData)
        if statusCode ~= 200 or not resultData then
            botIdentityCache = {}
            cb(botIdentityCache)
            return
        end

        local ok, decoded = pcall(json.decode, resultData)
        if not ok or not decoded then
            botIdentityCache = {}
            cb(botIdentityCache)
            return
        end

        local logoUrl = nil
        if decoded.avatar then
            local ext = decoded.avatar:sub(1, 2) == 'a_' and 'gif' or 'png'
            logoUrl = 'https://cdn.discordapp.com/avatars/' .. decoded.id .. '/' .. decoded.avatar .. '.' .. ext .. '?size=128'
        end

        botIdentityCache = { logoUrl = logoUrl, name = decoded.username }
        cb(botIdentityCache)
    end, 'GET', '', {
        ['Authorization'] = 'Bot ' .. token,
        ['Content-Type'] = 'application/json',
    })
end)

-----------------------------------------------------------------------
-- all registered players (online + offline), for the Players management page
-----------------------------------------------------------------------
-- a ban counts as active while os.time() < expire, matching the same check
-- RSGCore.Functions.IsPlayerBanned uses on connect; adminmenu's own ban action
-- (below) writes 2524608000 as its "permanent" sentinel, so treat anything
-- that far out as permanent for badge/filter purposes
local PERMANENT_BAN_THRESHOLD = 2524608000

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getallplayersmanaged', function(source, cb)
    MySQL.query('SELECT id, license, reason, expire, bannedby FROM bans', {}, function(banRows)
        local banByLicense = {}
        local now = os.time()
        for _, ban in ipairs(banRows or {}) do
            if ban.license and now < ban.expire then
                banByLicense[ban.license] = ban
            end
        end

        MySQL.query([[
            SELECT p.citizenid, p.name, p.license, p.charinfo, p.job, p.money, pt.minutes, pt.last_seen
            FROM players p
            LEFT JOIN player_playtime pt ON pt.citizenid = p.citizenid
            ORDER BY p.name ASC
        ]], {}, function(rows)
            local result = {}
            for _, row in ipairs(rows or {}) do
                local ok1, charinfo = pcall(json.decode, row.charinfo or '{}')
                local ok2, job = pcall(json.decode, row.job or '{}')
                local ok3, money = pcall(json.decode, row.money or '{}')
                charinfo = ok1 and charinfo or {}
                job = ok2 and job or {}
                money = ok3 and money or {}

                local onlinePlayer = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)

                -- an online player's DB row is only as fresh as their last autosave, so a
                -- bank deposit/admin adjustment won't show here until the next save fires —
                -- read the live session money instead whenever they're connected.
                local liveMoney = (onlinePlayer and onlinePlayer.PlayerData.money) or money
                local moneyTotal = 0
                for _, v in pairs(liveMoney) do
                    if type(v) == 'number' then moneyTotal = moneyTotal + v end
                end

                local discordId, discordName, discordAvatarUrl = nil, nil, nil
                if onlinePlayer then
                    discordId, discordName, discordAvatarUrl = GetCachedDiscordIdentity(onlinePlayer.PlayerData.source)
                end

                local ban = row.license and banByLicense[row.license] or nil

                result[#result + 1] = {
                    citizenid = row.citizenid,
                    serverId = onlinePlayer and onlinePlayer.PlayerData.source or nil,
                    name = (charinfo.firstname or '?') .. ' ' .. (charinfo.lastname or ''),
                    accountName = row.name or '',
                    job = onlinePlayer and onlinePlayer.PlayerData.job.label or (job.label or locale('sv_unemployed')),
                    money = moneyTotal,
                    playtimeMinutes = row.minutes or 0,
                    lastSeen = row.last_seen,
                    online = onlinePlayer ~= nil,
                    discordId = discordId,
                    discordName = discordName,
                    discordAvatarUrl = discordAvatarUrl,
                    banned = ban ~= nil,
                    banId = ban and ban.id or nil,
                    banReason = ban and ban.reason or nil,
                    banExpire = ban and ban.expire or nil,
                    banPermanent = ban and (ban.expire >= PERMANENT_BAN_THRESHOLD) or nil,
                    bannedBy = ban and ban.bannedby or nil,
                }
            end
            cb(result)
        end)
    end)
end)

-----------------------------------------------------------------------
-- unban — no existing unban path anywhere in the framework, so this
-- mirrors the same DELETE FROM bans WHERE id = ? cleanup RSGCore's own
-- IsPlayerBanned already does when a ban naturally expires
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:unbanplayer', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['ban']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false })
        return
    end

    MySQL.update('DELETE FROM bans WHERE id = ?', { data.banId }, function(affected)
        local success = affected > 0
        if success then
            LogAdminAction('player_action', 'medium', src, locale('sv_log_unbanned_player'), locale('sv_log_ban_id', tostring(data.banId)), nil)
        end
        cb({ success = success })
    end)
end)

-----------------------------------------------------------------------
-- admin menu command
-----------------------------------------------------------------------
RSGCore.Commands.Add('adminmenu', locale('sv_100'), {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.charinfo then
        return
    end
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['adminmenu']) or IsPlayerAceAllowed(src, 'god') then
        local discordId = RSGCore.Functions.GetIdentifier(src, 'discord')
        if discordId then
            discordId = discordId:gsub('discord:', '')
        end

        local canManageHistory = CanManageHistory(src)
        -- role-tier flags shipped to the UI once per open, so it can hide sections/pages
        -- a role has no access to — the server-side `permissions` table below is the
        -- real authorization boundary; these only drive what the UI shows
        local roleFlags = {
            canManageHistory = canManageHistory,
            canManageAdmins = canManageHistory, -- same allow-list (Owner/Head Admin): admin CRUD + Set Permission
            atLeastMod = RSGCore.Functions.HasPermission(src, 'mod') or IsPlayerAceAllowed(src, 'god'),
            atLeastAdmin = RSGCore.Functions.HasPermission(src, 'admin') or IsPlayerAceAllowed(src, 'god'),
            fullAccess = RSGCore.Functions.HasPermission(src, 'headadmin') or RSGCore.Functions.HasPermission(src, 'developer') or IsPlayerAceAllowed(src, 'god'),
        }
        ResolveDiscordName(discordId, function(discordName, discordAvatar)
            TriggerClientEvent('rsg-adminmenu:client:openadminmenu', src, { discordName = discordName, discordAvatar = discordAvatar, roleFlags = roleFlags })
        end)
    else
        --BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_d'), 'red',
            firstname .. ' ' .. lastname .. ' ' .. locale('sv_e') .. ' ' .. citizenid .. ' ' .. locale('sv_f'), true)
        TriggerClientEvent('ox_lib:notify', source,
            { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- revive player
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:playerrevive', function(player)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['revive']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-medic:client:adminRevive', player.id)
        LogAdminAction('player_action', 'low', src, locale('sv_log_revived_player'), nil, GetPlayerName(player.id), player.id)
    else
        BanPlayer(src)
        TriggerClientEvent('ox_lib:notify', source,
            { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
            firstname .. ' ' .. lastname .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_i'), true)
    end
end)

-----------------------------------------------------------------------
-- open players inventory
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:openinventory', function(player)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['inventory']) or IsPlayerAceAllowed(src, 'god') then
        exports['rsg-inventory']:OpenInventoryById(src, tonumber(player.id))
        LogAdminAction('player_action', 'low', src, locale('sv_log_opened_player_inventory'), nil, GetPlayerName(player.id), player.id)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
            firstname .. ' ' .. lastname .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_j'), true)
        TriggerClientEvent('ox_lib:notify', source,
            { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- kick player
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:kickplayer', function(player, reason)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['kick']) or IsPlayerAceAllowed(src, 'god') then
        local targetPlayer = RSGCore.Functions.GetPlayer(player)
        if targetPlayer then
            LogPlayerHistory(targetPlayer.PlayerData.citizenid, 'kick', reason, AdminDisplayName(src), nil)
        end
        TriggerEvent('rsg-log:server:CreateLog', 'bans', locale('sv_kicked'), 'red',
            string.format(locale('sv_kicked_a'), GetPlayerName(player), GetPlayerName(src), reason), true)
        LogAdminAction('player_action', 'medium', src, locale('sv_log_kicked_player'), reason, GetPlayerName(player), player)
        DropPlayer(player,
            locale('sv_103') .. ':\n' .. reason .. '\n\n' .. locale('sv_104') .. RSGCore.Config.Server.Discord)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
            firstname .. ' ' .. lastname .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_kicked_b'),
            true)
        TriggerClientEvent('ox_lib:notify', source,
            { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

RegisterNetEvent('rsg-adminmenu:server:banplayer', function(player, time, reason)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['ban']) or IsPlayerAceAllowed(src, 'god') then
        time = tonumber(time)
        local banTime = tonumber(os.time() + time)
        if banTime > 2524608000 then
            banTime = 2524608000
        end
        local timeTable = os.date('*t', banTime)
        local targetPlayer = RSGCore.Functions.GetPlayer(player)
        if targetPlayer then
            LogPlayerHistory(targetPlayer.PlayerData.citizenid, 'ban', reason, AdminDisplayName(src), time)
        end
        MySQL.insert(
        'INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            GetPlayerName(player),
            RSGCore.Functions.GetIdentifier(player, 'license'),
            RSGCore.Functions.GetIdentifier(player, 'discord'),
            RSGCore.Functions.GetIdentifier(player, 'ip'),
            reason,
            banTime,
            GetPlayerName(src)
        })
        TriggerClientEvent('chat:addMessage', -1, {
            template = "<div class=chat-message server'><strong>" ..
            locale('sv_ban') .. " | {0}" .. locale('sv_ban_a') .. ":</strong> {1}</div>",
            args = { GetPlayerName(player), reason }
        })
        TriggerEvent('rsg-log:server:CreateLog', 'bans', locale('sv_a'), 'red',
            string.format(locale('sv_b'), GetPlayerName(player), GetPlayerName(src), reason), true)
        LogAdminAction('player_action', 'high', src, locale('sv_log_banned_player'), locale('sv_log_ban_details', reason, tostring(time)), GetPlayerName(player), player)
        if banTime >= 2524608000 then
            DropPlayer(player,
                locale('sv_106') ..
                '\n' .. reason .. '\n\n' .. locale('sv_107') .. '\n' .. locale('sv_108') .. RSGCore.Config.Server
                .Discord)
        else
            DropPlayer(player,
                locale('sv_106') ..
                '\n' ..
                reason ..
                '\n\n' ..
                locale('sv_109') ..
                timeTable['day'] ..
                '/' ..
                timeTable['month'] ..
                '/' ..
                timeTable['year'] ..
                ' ' ..
                timeTable['hour'] .. ':' .. timeTable['min'] .. '\n' .. locale('sv_110') .. RSGCore.Config.Server
                .Discord)
        end
    else
        BanPlayer(src)
    end
end)

-----------------------------------------------------------------------
-- goto player
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:gotoplayer', function(player)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['goto']) or IsPlayerAceAllowed(src, 'god') then
        local admin = GetPlayerPed(src)
        local coords = GetEntityCoords(GetPlayerPed(player.id))
        SetEntityCoords(admin, coords)
        LogAdminAction('player_action', 'low', src, locale('sv_log_teleported_to_player'), nil, GetPlayerName(player.id), player.id)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
            firstname .. ' ' .. lastname .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_ban_c'), true)
        TriggerClientEvent('ox_lib:notify', source,
            { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- bring player
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:bringplayer', function(player)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['bring']) or IsPlayerAceAllowed(src, 'god') then
        local admin = GetPlayerPed(src)
        local coords = GetEntityCoords(admin)
        local target = GetPlayerPed(player.id)
        SetEntityCoords(target, coords)
        LogAdminAction('player_action', 'low', src, locale('sv_log_brought_player_to_self'), nil, GetPlayerName(player.id), player.id)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
            firstname .. ' ' .. lastname .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_ban_d'), true)
        TriggerClientEvent('ox_lib:notify', source,
            { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- freeze player
----------------------------------------------------------------------
local frozenPlayers = {}
RegisterNetEvent('rsg-adminmenu:server:freezeplayer', function(player)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['freeze']) or IsPlayerAceAllowed(src, 'god') then
        local target = GetPlayerPed(player.id)
        if not frozenPlayers[player.id] then
            frozenPlayers[player.id] = true
            FreezeEntityPosition(target, true)
            TriggerClientEvent('ox_lib:notify', source,
                { title = locale('sv_111'), description = locale('sv_112') .. player.name, type = 'inform' })
            LogAdminAction('player_action', 'low', src, locale('sv_log_froze_player'), nil, player.name, player.id)
        else
            frozenPlayers[player.id] = nil
            FreezeEntityPosition(target, false)
            TriggerClientEvent('ox_lib:notify', source,
                { title = locale('sv_113'), description = locale('sv_114') .. player.name, type = 'inform' })
            LogAdminAction('player_action', 'low', src, locale('sv_log_unfroze_player'), nil, player.name, player.id)
        end
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
            firstname .. ' ' .. lastname .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_ban_e'), true)
        TriggerClientEvent('ox_lib:notify', source,
            { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- spectate player
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:spectateplayer', function(player)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['spectate']) or IsPlayerAceAllowed(src, 'god') then
        local targetped = GetPlayerPed(player.id)
        local coords = GetEntityCoords(targetped)
        TriggerClientEvent('rsg-adminmenu:client:spectateplayer', src, player.id, coords)
        LogAdminAction('player_action', 'low', src, locale('sv_log_started_spectating_player'), nil, GetPlayerName(player.id), player.id)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
            firstname .. ' ' .. lastname .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_ban_f'), true)
        TriggerClientEvent('ox_lib:notify', source,
            { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- wild attack
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:wildattack', function(player)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['wildattack']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-adminmenu:client:wildattack', src, player.id)
        LogAdminAction('player_action', 'medium', src, locale('sv_log_triggered_wild_animal_attack_on_player'), nil, GetPlayerName(player.id), player.id)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
            firstname .. ' ' .. lastname .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_ban_g'), true)
        TriggerClientEvent('ox_lib:notify', source,
            { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- set player on fire
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:playerfire', function(player)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['setonfire']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-adminmenu:client:playerfire', src, player.id)
        LogAdminAction('player_action', 'medium', src, locale('sv_log_set_player_on_fire'), nil, GetPlayerName(player.id), player.id)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
            firstname .. ' ' .. lastname .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_ban_h'), true)
        TriggerClientEvent('ox_lib:notify', source,
            { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- give item
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:giveitem', function(player, item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['giveitem']) or IsPlayerAceAllowed(src, 'god') then
        local id = player
        local Player_a = RSGCore.Functions.GetPlayer(id)
        local amount_a = amount
        Player_a.Functions.AddItem(item, amount_a)
        TriggerClientEvent('ox_lib:notify', src,
            { title = locale('sv_135'), description = locale('sv_136'), type = 'inform' })
        LogAdminAction('player_action', 'medium', src, locale('sv_log_gave_item_to_player'), item .. ' x' .. tostring(amount_a), GetPlayerName(id), id)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
            firstname .. ' ' .. lastname .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_ban_i'), true)
        TriggerClientEvent('ox_lib:notify', src,
            { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- player info
----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getplayerinfo', function(source, cb, player)
    local src = source
    local adminPlayer = RSGCore.Functions.GetPlayer(src)
    local firstname = adminPlayer.PlayerData.charinfo.firstname
    local lastname = adminPlayer.PlayerData.charinfo.lastname
    local citizenid = adminPlayer.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['playerinfo']) or IsPlayerAceAllowed(src, 'god') then
        local id               = player.id
        local targetPlayer     = RSGCore.Functions.GetPlayer(id)
        local targetfirstname  = targetPlayer.PlayerData.charinfo.firstname
        local targetlastname   = targetPlayer.PlayerData.charinfo.lastname
        local targetjob        = targetPlayer.PlayerData.job.label
        local targetgrade      = targetPlayer.PlayerData.job.grade.level
        local targetcash       = targetPlayer.PlayerData.money['cash']
        local targetbloodmoney = targetPlayer.PlayerData.money['bloodmoney']
        local targetbank       = targetPlayer.PlayerData.money['bank']
        local targetvalbank    = targetPlayer.PlayerData.money['valbank']
        local targetrhobank    = targetPlayer.PlayerData.money['rhobank']
        local targetblkbank    = targetPlayer.PlayerData.money['blkbank']
        local targetarmbank    = targetPlayer.PlayerData.money['armbank']
        local targetcitizenid  = targetPlayer.PlayerData.citizenid
        local targetserverid   = id

        local discordId, discordName, discordAvatarUrl = GetCachedDiscordIdentity(id)

        local availablePermissions = {}
        for _, level in ipairs(RSGCore.Config.Server.Permissions) do
            availablePermissions[#availablePermissions + 1] = { value = level, label = LabelForRole(level) }
        end

        local items = {}
        for _, item in pairs(targetPlayer.PlayerData.items or {}) do
            if item then
                local itemDef = RSGCore.Shared.Items[item.name:lower()]
                items[#items + 1] = {
                    slot = item.slot,
                    name = item.name,
                    label = (itemDef and itemDef.label) or item.name,
                    image = itemDef and itemDef.image or nil,
                    amount = item.amount,
                    weight = (itemDef and itemDef.weight) or 0,
                }
            end
        end

        cb({
            firstname          = targetfirstname,
            lastname           = targetlastname,
            job                = targetjob,
            grade              = targetgrade,
            jobGradeName        = targetPlayer.PlayerData.job.grade.name,
            cash               = targetcash,
            bloodmoney         = targetbloodmoney,
            bank               = targetbank,
            valbank            = targetvalbank,
            rhobank            = targetrhobank,
            blkbank            = targetblkbank,
            armbank            = targetarmbank,
            citizenid          = targetcitizenid,
            serverid           = targetserverid,
            role               = GetPlayerRole(id),
            roleLabel          = LabelForRole(GetPlayerRole(id)),
            availablePermissions = availablePermissions,
            ping               = GetPlayerPing(id),
            steamHex           = RSGCore.Functions.GetIdentifier(id, 'steam'),
            ip                 = RSGCore.Functions.GetIdentifier(id, 'ip'),
            discordId          = discordId,
            discordName        = discordName,
            discordAvatarUrl   = discordAvatarUrl,
            items              = items,
        })
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
            firstname .. ' ' .. lastname .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_ban_j'), true)
        TriggerClientEvent('ox_lib:notify', src,
            { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- shared anti-tamper helper for the actions below — same BanPlayer + rsg-log +
-- notify sequence every handler above repeats inline, factored out since there
-- are 15 of these and they'd otherwise be near-identical copy/paste
-----------------------------------------------------------------------
local function DenyAndBan(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid
    BanPlayer(src)
    TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
        firstname .. ' ' .. lastname .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_ban_k'), true)
    TriggerClientEvent('ox_lib:notify', src,
        { title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    LogAdminAction('security', 'high', src, locale('sv_log_unauthorized_action_attempt_auto_banned'), locale('sv_log_citizen_id', citizenid), firstname .. ' ' .. lastname)
end

-----------------------------------------------------------------------
-- heal (health only, distinct from the existing death/revive flow)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:healplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['heal']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-medic:client:adminHeal', player.id)
        LogAdminAction('player_action', 'low', src, locale('sv_log_healed_player'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

-----------------------------------------------------------------------
-- kill (entity health is networked, so — like GoTo/Bring/Freeze above —
-- this is a direct server-side native call, no client relay needed)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:killplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['kill']) or IsPlayerAceAllowed(src, 'god') then
        SetEntityHealth(GetPlayerPed(player.id), 0)
        LogAdminAction('player_action', 'medium', src, locale('sv_log_killed_player'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

-----------------------------------------------------------------------
-- ragdoll / lightning / drain stamina / drunk
-- (novelty status-effect actions — no precedent elsewhere in the framework;
-- these need camera/stamina/ragdoll-state natives that only work on the
-- target's own client, so they're relayed via client_playeractions.lua)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:ragdollplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['ragdoll']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-adminmenu:client:ragdollplayer', player.id)
        LogAdminAction('player_action', 'low', src, locale('sv_log_ragdolled_player'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

RegisterNetEvent('rsg-adminmenu:server:lightningplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['lightning']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-adminmenu:client:lightningplayer', player.id)
        LogAdminAction('player_action', 'low', src, locale('sv_log_struck_player_with_lightning'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

-- position is networked too, so this is a direct server-side coord bump —
-- same GetPlayerPed/SetEntityCoords pattern already used by GoTo/Bring above
RegisterNetEvent('rsg-adminmenu:server:toheavenplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['toheaven']) or IsPlayerAceAllowed(src, 'god') then
        local target = GetPlayerPed(player.id)
        local coords = GetEntityCoords(target)
        SetEntityCoords(target, coords.x, coords.y, coords.z + 300.0)
        LogAdminAction('player_action', 'low', src, locale('sv_log_launched_player_skyward'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

RegisterNetEvent('rsg-adminmenu:server:drainstaminaplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['drainstamina']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-adminmenu:client:drainstaminaplayer', player.id)
        LogAdminAction('player_action', 'low', src, locale('sv_log_drained_player_stamina'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

RegisterNetEvent('rsg-adminmenu:server:drunkplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['drunk']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-adminmenu:client:drunkplayer', player.id)
        LogAdminAction('player_action', 'low', src, locale('sv_log_applied_drunk_effect_to_player'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

-----------------------------------------------------------------------
-- jump scare / horse buck / haunted / make everyone attack
-- (more novelty status-effect actions, same relay pattern as the ones above —
-- see client_playeractions.lua for the actual native calls)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:jumpscareplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['jumpscare']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-adminmenu:client:jumpscareplayer', player.id)
        LogAdminAction('player_action', 'low', src, locale('sv_log_jump_scared_player'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

RegisterNetEvent('rsg-adminmenu:server:horsebuckplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['horsebuck']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-adminmenu:client:horsebuckplayer', player.id)
        LogAdminAction('player_action', 'low', src, locale('sv_log_bucked_player_from_horse'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

RegisterNetEvent('rsg-adminmenu:server:hauntedplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['haunted']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-adminmenu:client:hauntedplayer', player.id)
        LogAdminAction('player_action', 'low', src, locale('sv_log_applied_haunted_effect_to_player'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

RegisterNetEvent('rsg-adminmenu:server:everyoneattackplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['everyoneattack']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-adminmenu:client:everyoneattackplayer', player.id)
        LogAdminAction('player_action', 'medium', src, locale('sv_log_made_everyone_attack_player'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

-----------------------------------------------------------------------
-- handcuff — reuses rsg-lawman's cuff flow directly rather than rebuilding
-- it; that handler owns the toggle state itself and syncs
-- 'ishandcuffed' metadata via its own rsg-lawman:server:sethandcuffstatus
-- event, so this is just a relay
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:handcuffplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['handcuff']) or IsPlayerAceAllowed(src, 'god') then
        TriggerClientEvent('rsg-lawman:client:getcuffed', player.id, src, false)
        LogAdminAction('player_action', 'low', src, locale('sv_log_handcuffed_uncuffed_player'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

-----------------------------------------------------------------------
-- warn player — logged to admin_player_history (shown in the History tab
-- alongside kicks/bans), doesn't kick or disconnect them, just a notice
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:warnplayer', function(player, reason, severity)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['warn']) or IsPlayerAceAllowed(src, 'god') then
        local targetPlayer = RSGCore.Functions.GetPlayer(player.id)
        if targetPlayer then
            LogPlayerHistory(targetPlayer.PlayerData.citizenid, 'warn', reason, AdminDisplayName(src), nil, severity)
            TriggerClientEvent('ox_lib:notify', player.id,
                { title = locale('sv_you_have_been_warned'), description = reason, type = 'error' })
            LogAdminAction('player_action', severity or 'medium', src, locale('sv_log_warned_player'), reason, GetPlayerName(player.id), player.id)
        end
    else
        DenyAndBan(src)
    end
end)

-----------------------------------------------------------------------
-- set permission level (replaces, rather than stacks — clears every
-- configured level first so this behaves like a single role selector)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:setpermission', function(player, level)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['setpermission']) or IsPlayerAceAllowed(src, 'god') then
        local admin = RSGCore.Functions.GetPlayer(src)
        local adminName = admin.PlayerData.charinfo.firstname .. ' ' .. admin.PlayerData.charinfo.lastname
        local target = RSGCore.Functions.GetPlayer(player.id)
        local targetName = target and (target.PlayerData.charinfo.firstname .. ' ' .. target.PlayerData.charinfo.lastname) or GetPlayerName(player.id)

        -- routes through the same admin_roles table the Admins page reads/writes,
        -- so a role set here and a role set from the Admins page can never drift apart
        if level and level ~= '' then
            SetAdminRole(target.PlayerData.citizenid, player.id, level, adminName, RSGCore.Functions.GetIdentifier(player.id, 'discord'), targetName)
        else
            RemoveAdminRole(target.PlayerData.citizenid, player.id)
        end

        local levelLabel = (level and level ~= '') and LabelForRole(level) or locale('sv_role_user')
        TriggerClientEvent('ox_lib:notify', src,
            { title = locale('sv_permission_updated'), description = locale('sv_permission_set_to', levelLabel), type = 'success' })
        LogAdminAction('admin_action', 'high', src, locale('sv_log_changed_player_permission_level'), locale('sv_log_new_level', levelLabel), targetName, player.id)
    else
        DenyAndBan(src)
    end
end)

-----------------------------------------------------------------------
-- set job
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:setjob', function(player, job, grade)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['setjob']) or IsPlayerAceAllowed(src, 'god') then
        local targetPlayer = RSGCore.Functions.GetPlayer(player.id)
        if targetPlayer then
            targetPlayer.Functions.SetJob(job, tonumber(grade) or 0)
            LogAdminAction('player_action', 'medium', src, locale('sv_log_changed_player_job'), locale('sv_log_job_grade', tostring(job), tostring(grade)), GetPlayerName(player.id), player.id)
        end
    else
        DenyAndBan(src)
    end
end)

-----------------------------------------------------------------------
-- set charinfo field (nickname/firstname/lastname/age/description share one
-- handler — charinfo is a free-form JSON column so new keys need no migration)
-----------------------------------------------------------------------
local allowedCharFields = { nickname = true, firstname = true, lastname = true, age = true, description = true }
RegisterNetEvent('rsg-adminmenu:server:setcharfield', function(player, field, value)
    local src = source
    if not allowedCharFields[field] then return end
    if RSGCore.Functions.HasPermission(src, permissions['setcharfield']) or IsPlayerAceAllowed(src, 'god') then
        local targetPlayer = RSGCore.Functions.GetPlayer(player.id)
        if targetPlayer then
            targetPlayer.PlayerData.charinfo[field] = value
            targetPlayer.Functions.UpdatePlayerData()
            targetPlayer.Functions.Save()
            LogAdminAction('player_action', 'medium', src, locale('sv_log_changed_player_character_field'), field .. ' = ' .. tostring(value), GetPlayerName(player.id), player.id)
        end
    else
        DenyAndBan(src)
    end
end)

-----------------------------------------------------------------------
-- add/remove xp (no leveling system exists in rsg-core — stored under
-- PlayerData.metadata, the same free-form JSON store SetMetaData/GetMetaData use)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:adjustxp', function(player, direction, amount)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['xp']) or IsPlayerAceAllowed(src, 'god') then
        local targetPlayer = RSGCore.Functions.GetPlayer(player.id)
        if targetPlayer then
            local current = tonumber(targetPlayer.Functions.GetMetaData('xp')) or 0
            local delta = tonumber(amount) or 0
            local newXp = direction == 'remove' and math.max(0, current - delta) or current + delta
            targetPlayer.Functions.SetMetaData('xp', newXp)
            LogAdminAction('economy', 'low', src, locale('sv_log_adjusted_player_xp'), (direction == 'remove' and '-' or '+') .. tostring(delta) .. ' (new: ' .. tostring(newXp) .. ')', GetPlayerName(player.id), player.id)
        end
    else
        DenyAndBan(src)
    end
end)

-----------------------------------------------------------------------
-- clear weapons / clear items
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:clearweapons', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['clearweapons']) or IsPlayerAceAllowed(src, 'god') then
        local targetPlayer = RSGCore.Functions.GetPlayer(player.id)
        if targetPlayer then
            for _, item in pairs(targetPlayer.PlayerData.items or {}) do
                if item and RSGCore.Shared.Items[item.name:lower()] and RSGCore.Shared.Items[item.name:lower()].type == 'weapon' then
                    exports['rsg-inventory']:RemoveItem(player.id, item.name, item.amount, item.slot, locale('sv_admin_cleared_weapons'), false)
                end
            end
        end
        TriggerClientEvent('rsg-adminmenu:client:clearweapons', player.id)
        LogAdminAction('player_action', 'medium', src, locale('sv_log_cleared_player_weapons'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

RegisterNetEvent('rsg-adminmenu:server:clearitems', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['clearitems']) or IsPlayerAceAllowed(src, 'god') then
        exports['rsg-inventory']:ClearInventory(player.id)
        LogAdminAction('player_action', 'medium', src, locale('sv_log_cleared_player_items'), nil, GetPlayerName(player.id), player.id)
    else
        DenyAndBan(src)
    end
end)

-----------------------------------------------------------------------
-- item catalog (for the "select item to add" picker) + per-slot inventory removal
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getallitems', function(source, cb)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['giveitem']) or IsPlayerAceAllowed(src, 'god')) then
        cb({})
        return
    end

    local items = {}
    for name, item in pairs(RSGCore.Shared.Items) do
        items[#items + 1] = {
            name = name,
            label = item.label or name,
            image = item.image,
            type = item.type or 'item',
            weight = item.weight or 0,
            category = item.category,
        }
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    cb(items)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:removeplayeritem', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['giveitem']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false })
        return
    end

    local removed = exports['rsg-inventory']:RemoveItem(data.id, data.item, data.amount, data.slot, locale('sv_admin_removed_item'), false)
    if removed then
        LogAdminAction('player_action', 'medium', src, locale('sv_log_removed_item_from_player'), data.item .. ' x' .. tostring(data.amount), GetPlayerName(data.id), data.id)
    end
    cb({ success = removed and true or false })
end)

-----------------------------------------------------------------------
-- Command to open the report menu
-----------------------------------------------------------------------
RSGCore.Commands.Add('report', locale('sv_report_command_desc'), {}, false, function(source)
    local src = source
    TriggerClientEvent('rsg-adminmenu:client:openreportmenu', src)
end)