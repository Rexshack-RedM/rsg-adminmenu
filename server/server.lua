local RSGCore = exports['rsg-core']:GetCoreObject()

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
    ['reports'] = 'helper', -- view, claim, reply to and close player reports
    ['selftools'] = 'helper', -- godmode, invisible, self revive, player blips, door IDs, teleport to marker
    ['viewip'] = 'admin', -- see a player's IP in the manage modal
    ['worldtools'] = 'mod', -- Live Map, Teleports, Blips, Spawner mutations (Coords/self-teleport is helper via 'playerinfo'/'goto')
    -- 'headadmin' alone would lock this out on RSGCore's shipped server.cfg
    -- template (it only wires up god/developer/admin/mod/helper groups), so
    -- 'god' is the real top tier in practice.
    ['serversettings'] = { 'god', 'headadmin', 'developer' }, -- server actions, time/weather/wind/timescale, resource management, Master Actions
}

local PERMANENT_BAN = 2524608000 -- expire timestamp used as "permanent" (matches RSGCore's ban check)
local MAX_GIVE_AMOUNT = 1000
-- cash and bloodmoney are items on this server: they must go through AddMoney (Finances), never AddItem
local MONEY_ITEMS = { dollar = true, cent = true, blood_dollar = true, blood_cent = true }

-----------------------------------------------------------------------
-- shared helpers (global so the other server files use the same checks)
-----------------------------------------------------------------------
function HasAdminPermission(src, action)
    return RSGCore.Functions.HasPermission(src, permissions[action]) or IsPlayerAceAllowed(src, 'god')
end

function NotifyPlayer(src, title, description, notifyType, duration)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = title, description = description, type = notifyType or 'inform', duration = duration })
end

-- trims, caps and stringifies free text coming from the NUI
function SanitizeText(value, maxLength)
    if value == nil then return nil end
    local text = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return nil end
    return text:sub(1, maxLength or 255)
end

-- accepts a raw server id or the { id = x } table the NUI sends; returns the id only if that player is online
local function ResolveTarget(player)
    local id = tonumber(type(player) == 'table' and player.id or player)
    if not id or not RSGCore.Functions.GetPlayer(id) then return nil end
    return id
end

local function BanPlayer(src)
    MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        GetPlayerName(src),
        RSGCore.Functions.GetIdentifier(src, 'license'),
        RSGCore.Functions.GetIdentifier(src, 'discord'),
        RSGCore.Functions.GetIdentifier(src, 'ip'),
        locale('sv_system_banned_you'),
        PERMANENT_BAN,
        'rsg-adminmenu',
    })
    TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_a'), 'red',
        string.format(locale('sv_b'), GetPlayerName(src), 'rsg-adminmenu', locale('sv_c')), true)
    DropPlayer(src, locale('sv_105'))
end

-- a client fired an admin event it has no permission for: log and ban
local function DenyAndBan(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    local name = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or GetPlayerName(src)
    local citizenid = Player and Player.PlayerData.citizenid or '?'
    TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
        name .. ' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_ban_k'), true)
    LogAdminAction('security', 'high', src, locale('sv_log_unauthorized_action_attempt_auto_banned'), locale('sv_log_citizen_id', citizenid), name)
    BanPlayer(src)
end

-- registers a net event that acts on another player: permission check (ban on
-- failure), target must be online, and protected actions can't be used on
-- staff of the same or a higher rank
local function RegisterPlayerAction(event, action, protected, handler)
    RegisterNetEvent('rsg-adminmenu:server:' .. event, function(player, ...)
        local src = source
        if not HasAdminPermission(src, action) then return DenyAndBan(src) end
        local target = ResolveTarget(player)
        if not target then
            return NotifyPlayer(src, locale('sv_101'), locale('sv_player_not_online'), 'error')
        end
        if protected and not CanActOn(src, target) then
            return NotifyPlayer(src, locale('sv_101'), locale('sv_target_higher_rank'), 'error')
        end
        handler(src, target, ...)
    end)
end

-----------------------------------------------------------------------
-- get players function
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getplayers', function(source, cb)
    if not HasAdminPermission(source, 'adminmenu') then return cb({}) end
    local players = {}
    for _, v in pairs(RSGCore.Functions.GetPlayers()) do
        local Player = RSGCore.Functions.GetPlayer(v)
        if Player then
            players[#players + 1] = {
                name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' | (' .. GetPlayerName(v) .. ')',
                id = v,
                coords = GetEntityCoords(GetPlayerPed(v)),
                citizenid = Player.PlayerData.citizenid,
            }
        end
    end
    table.sort(players, function(a, b) return a.id < b.id end)
    cb(players)
end)

-----------------------------------------------------------------------
-- resolve a discord:<id> identifier into the account's real Discord name
-----------------------------------------------------------------------
local discordNameCache = {}

local function GetBotToken()
    local token = Config.DiscordBot and Config.DiscordBot.Token
    if not token or token == '' or token == 'TOKEN HERE' or token == 'YOUR_DISCORD_BOT_TOKEN_HERE' then return nil end
    return token
end

-- synchronous read for list/table rendering — only returns something once
-- ResolveDiscordName has warmed the cache for this id (on join, or on-demand elsewhere)
function GetCachedDiscordIdentity(source)
    local discordId = RSGCore.Functions.GetIdentifier(source, 'discord')
    if not discordId then return nil, nil, nil end
    discordId = discordId:gsub('discord:', '')
    local cached = discordNameCache[discordId]
    if not cached then return discordId, nil, nil end
    return discordId, cached.name, cached.avatarUrl
end

-- what shows as "By: ..." for an acting admin — Discord name when cached, else the account name
function AdminDisplayName(source)
    local _, discordName = GetCachedDiscordIdentity(source)
    return discordName or GetPlayerName(source)
end

function ResolveDiscordName(discordId, cb)
    if not discordId or discordId == '' then return cb(nil, nil) end

    local cached = discordNameCache[discordId]
    if cached then return cb(cached.name, cached.avatarUrl) end

    local token = GetBotToken()
    if not token then return cb(nil, nil) end

    PerformHttpRequest('https://discord.com/api/v10/users/' .. discordId, function(statusCode, resultData)
        if statusCode ~= 200 or not resultData then return cb(nil, nil) end

        local ok, decoded = pcall(json.decode, resultData)
        if not ok or not decoded then return cb(nil, nil) end

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
-- warm the discord name/avatar cache on connect, throttled to ~6/s so a
-- burst of joins (e.g. after a restart) never trips Discord's rate limit
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
    if not GetBotToken() then return end
    local discordId = RSGCore.Functions.GetIdentifier(Player.PlayerData.source, 'discord')
    if discordId then
        discordWarmQueue[#discordWarmQueue + 1] = discordId:gsub('discord:', '')
        ProcessDiscordWarmQueue()
    end
end)

-----------------------------------------------------------------------
-- the bot's own avatar, used as the sidebar logo
-----------------------------------------------------------------------
local botIdentityCache = nil

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getbotlogo', function(source, cb)
    if botIdentityCache ~= nil then return cb(botIdentityCache) end

    local token = GetBotToken()
    if not token then return cb({}) end

    PerformHttpRequest('https://discord.com/api/v10/users/@me', function(statusCode, resultData)
        local ok, decoded = false, nil
        if statusCode == 200 and resultData then
            ok, decoded = pcall(json.decode, resultData)
        end
        if not ok or not decoded then
            botIdentityCache = {}
            return cb(botIdentityCache)
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
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getallplayersmanaged', function(source, cb)
    if not HasAdminPermission(source, 'adminmenu') then return cb({}) end

    MySQL.query('SELECT id, license, reason, expire, bannedby FROM bans WHERE expire > ?', { os.time() }, function(banRows)
        local banByLicense = {}
        for _, ban in ipairs(banRows or {}) do
            if ban.license then banByLicense[ban.license] = ban end
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
                charinfo = ok1 and type(charinfo) == 'table' and charinfo or {}
                job = ok2 and type(job) == 'table' and job or {}
                money = ok3 and type(money) == 'table' and money or {}

                local onlinePlayer = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)

                -- an online player's DB row is only as fresh as their last autosave
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
                    banPermanent = ban and (ban.expire >= PERMANENT_BAN) or nil,
                    bannedBy = ban and ban.bannedby or nil,
                }
            end
            cb(result)
        end)
    end)
end)

-----------------------------------------------------------------------
-- unban (same DELETE RSGCore's own IsPlayerBanned does when a ban expires)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:unbanplayer', function(source, cb, data)
    local src = source
    if not HasAdminPermission(src, 'ban') then return cb({ success = false }) end
    local banId = tonumber(data and data.banId)
    if not banId then return cb({ success = false }) end

    MySQL.update('DELETE FROM bans WHERE id = ?', { banId }, function(affected)
        local success = (affected or 0) > 0
        if success then
            LogAdminAction('player_action', 'medium', src, locale('sv_log_unbanned_player'), locale('sv_log_ban_id', tostring(banId)), nil)
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
    if not Player then return end

    if not HasAdminPermission(src, 'adminmenu') then
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_d'), 'red',
            Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' ' .. locale('sv_e') .. ' ' .. Player.PlayerData.citizenid .. ' ' .. locale('sv_f'), true)
        return NotifyPlayer(src, locale('sv_101'), locale('sv_102'), 'error')
    end

    local discordId = RSGCore.Functions.GetIdentifier(src, 'discord')
    if discordId then discordId = discordId:gsub('discord:', '') end

    local canManageHistory = CanManageHistory(src)
    -- role-tier flags only drive what the UI shows; every action is re-checked on the server
    local roleFlags = {
        canManageHistory = canManageHistory,
        canManageAdmins = canManageHistory,
        atLeastMod = RSGCore.Functions.HasPermission(src, 'mod') or IsPlayerAceAllowed(src, 'god'),
        atLeastAdmin = RSGCore.Functions.HasPermission(src, 'admin') or IsPlayerAceAllowed(src, 'god'),
        fullAccess = HasAdminPermission(src, 'serversettings'),
    }
    ResolveDiscordName(discordId, function(discordName, discordAvatar)
        TriggerClientEvent('rsg-adminmenu:client:openadminmenu', src, { discordName = discordName, discordAvatar = discordAvatar, roleFlags = roleFlags })
    end)
end)

-----------------------------------------------------------------------
-- revive / heal / inventory / goto / bring / spectate
-----------------------------------------------------------------------
RegisterPlayerAction('playerrevive', 'revive', false, function(src, target)
    RSGCore.Functions.GetPlayer(target).Functions.SetMetaData('isdead', false)
    TriggerClientEvent('rsg-medic:client:revive', target)
    LogAdminAction('player_action', 'low', src, locale('sv_log_revived_player'), nil, GetPlayerName(target), target)
end)

RegisterPlayerAction('healplayer', 'heal', false, function(src, target)
    TriggerClientEvent('rsg-medic:client:heal', target, -1)
    LogAdminAction('player_action', 'low', src, locale('sv_log_healed_player'), nil, GetPlayerName(target), target)
end)

RegisterPlayerAction('openinventory', 'inventory', false, function(src, target)
    exports['rsg-inventory']:OpenInventoryById(src, target)
    LogAdminAction('player_action', 'low', src, locale('sv_log_opened_player_inventory'), nil, GetPlayerName(target), target)
end)

RegisterPlayerAction('gotoplayer', 'goto', false, function(src, target)
    SetEntityCoords(GetPlayerPed(src), GetEntityCoords(GetPlayerPed(target)))
    LogAdminAction('player_action', 'low', src, locale('sv_log_teleported_to_player'), nil, GetPlayerName(target), target)
end)

RegisterPlayerAction('bringplayer', 'bring', true, function(src, target)
    SetEntityCoords(GetPlayerPed(target), GetEntityCoords(GetPlayerPed(src)))
    LogAdminAction('player_action', 'low', src, locale('sv_log_brought_player_to_self'), nil, GetPlayerName(target), target)
end)

RegisterPlayerAction('spectateplayer', 'spectate', false, function(src, target)
    if target == src then return end
    TriggerClientEvent('rsg-adminmenu:client:spectateplayer', src, target, GetEntityCoords(GetPlayerPed(target)))
    LogAdminAction('player_action', 'low', src, locale('sv_log_started_spectating_player'), nil, GetPlayerName(target), target)
end)

-----------------------------------------------------------------------
-- freeze (toggle, tracked per target and cleared when they leave)
-----------------------------------------------------------------------
local frozenPlayers = {}

RegisterPlayerAction('freezeplayer', 'freeze', true, function(src, target)
    local name = GetPlayerName(target)
    local freeze = not frozenPlayers[target]
    frozenPlayers[target] = freeze or nil
    FreezeEntityPosition(GetPlayerPed(target), freeze)
    if freeze then
        NotifyPlayer(src, locale('sv_111'), locale('sv_112') .. name, 'inform')
        LogAdminAction('player_action', 'low', src, locale('sv_log_froze_player'), nil, name, target)
    else
        NotifyPlayer(src, locale('sv_113'), locale('sv_114') .. name, 'inform')
        LogAdminAction('player_action', 'low', src, locale('sv_log_unfroze_player'), nil, name, target)
    end
end)

AddEventHandler('playerDropped', function()
    frozenPlayers[source] = nil
end)

-----------------------------------------------------------------------
-- kick / ban
-----------------------------------------------------------------------
RegisterPlayerAction('kickplayer', 'kick', true, function(src, target, reason)
    reason = SanitizeText(reason, 255) or locale('sv_no_reason')
    local targetPlayer = RSGCore.Functions.GetPlayer(target)
    LogPlayerHistory(targetPlayer.PlayerData.citizenid, 'kick', reason, AdminDisplayName(src), nil)
    TriggerEvent('rsg-log:server:CreateLog', 'bans', locale('sv_kicked'), 'red',
        string.format(locale('sv_kicked_a'), GetPlayerName(target), GetPlayerName(src), reason), true)
    LogAdminAction('player_action', 'medium', src, locale('sv_log_kicked_player'), reason, GetPlayerName(target), target)
    DropPlayer(target, locale('sv_103') .. ':\n' .. reason .. '\n\n' .. locale('sv_104') .. (RSGCore.Config.Server.Discord or ''))
end)

RegisterPlayerAction('banplayer', 'ban', true, function(src, target, duration, reason)
    duration = math.floor(tonumber(duration) or 0)
    if duration <= 0 then
        return NotifyPlayer(src, locale('sv_101'), locale('sv_invalid_ban_duration'), 'error')
    end
    reason = SanitizeText(reason, 255) or locale('sv_no_reason')

    local banTime = math.min(os.time() + duration, PERMANENT_BAN)
    local permanent = banTime >= PERMANENT_BAN
    local targetName = GetPlayerName(target)
    local targetPlayer = RSGCore.Functions.GetPlayer(target)

    -- duration_seconds is INT(11): permanent bans store NULL instead of overflowing it
    LogPlayerHistory(targetPlayer.PlayerData.citizenid, 'ban', reason, AdminDisplayName(src), not permanent and duration or nil)
    MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        targetName,
        RSGCore.Functions.GetIdentifier(target, 'license'),
        RSGCore.Functions.GetIdentifier(target, 'discord'),
        RSGCore.Functions.GetIdentifier(target, 'ip'),
        reason,
        banTime,
        GetPlayerName(src),
    })
    TriggerClientEvent('chat:addMessage', -1, {
        template = "<div class='chat-message server'><strong>" .. locale('sv_ban') .. " | {0} " .. locale('sv_ban_a') .. ":</strong> {1}</div>",
        args = { targetName, reason },
    })
    TriggerEvent('rsg-log:server:CreateLog', 'bans', locale('sv_a'), 'red',
        string.format(locale('sv_b'), targetName, GetPlayerName(src), reason), true)
    LogAdminAction('player_action', 'high', src, locale('sv_log_banned_player'), locale('sv_log_ban_details', reason, permanent and locale('sv_permanent') or tostring(duration)), targetName, target)

    local discord = RSGCore.Config.Server.Discord or ''
    if permanent then
        DropPlayer(target, locale('sv_106') .. '\n' .. reason .. '\n\n' .. locale('sv_107') .. '\n' .. locale('sv_108') .. discord)
    else
        DropPlayer(target, locale('sv_106') .. '\n' .. reason .. '\n\n' .. locale('sv_109') .. os.date('%d/%m/%Y %H:%M', banTime) .. '\n' .. locale('sv_110') .. discord)
    end
end)

-----------------------------------------------------------------------
-- give item (validated against the item list, capacity checked first)
-----------------------------------------------------------------------
RegisterPlayerAction('giveitem', 'giveitem', false, function(src, target, item, amount)
    item = type(item) == 'string' and item:lower() or nil
    amount = math.floor(tonumber(amount) or 0)
    local itemDef = item and RSGCore.Shared.Items[item]
    if not itemDef or amount < 1 or amount > MAX_GIVE_AMOUNT then
        return NotifyPlayer(src, locale('sv_135'), locale('sv_invalid_item_or_amount', MAX_GIVE_AMOUNT), 'error')
    end
    if MONEY_ITEMS[item] then
        return NotifyPlayer(src, locale('sv_135'), locale('sv_use_finances_for_money'), 'error')
    end
    if not exports['rsg-inventory']:CanAddItem(target, item, amount) then
        return NotifyPlayer(src, locale('sv_135'), locale('sv_inventory_full'), 'error')
    end
    if not exports['rsg-inventory']:AddItem(target, item, amount, nil, nil, locale('sv_admin_gave_item')) then
        return NotifyPlayer(src, locale('sv_135'), locale('sv_inventory_full'), 'error')
    end
    NotifyPlayer(src, locale('sv_135'), locale('sv_136'), 'success')
    LogAdminAction('player_action', 'medium', src, locale('sv_log_gave_item_to_player'), item .. ' x' .. amount, GetPlayerName(target), target)
end)

-----------------------------------------------------------------------
-- player info
-----------------------------------------------------------------------
local moneyTypes = { 'cash', 'bloodmoney', 'bank', 'valbank', 'rhobank', 'blkbank', 'armbank' }

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getplayerinfo', function(source, cb, player)
    local src = source
    if not HasAdminPermission(src, 'playerinfo') then return cb({}) end
    local id = ResolveTarget(player)
    if not id then return cb({}) end

    local targetPlayer = RSGCore.Functions.GetPlayer(id)
    local pd = targetPlayer.PlayerData
    local discordId, discordName, discordAvatarUrl = GetCachedDiscordIdentity(id)

    local availablePermissions = {}
    for _, level in ipairs(RSGCore.Config.Server.Permissions) do
        availablePermissions[#availablePermissions + 1] = { value = level, label = LabelForRole(level) }
    end

    local items = {}
    for _, item in pairs(pd.items or {}) do
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

    local role = GetPlayerRole(id)
    local info = {
        firstname = pd.charinfo.firstname,
        lastname = pd.charinfo.lastname,
        job = pd.job.label,
        grade = pd.job.grade.level,
        jobGradeName = pd.job.grade.name,
        citizenid = pd.citizenid,
        serverid = id,
        role = role,
        roleLabel = LabelForRole(role),
        availablePermissions = availablePermissions,
        ping = GetPlayerPing(id),
        steamHex = RSGCore.Functions.GetIdentifier(id, 'steam'),
        ip = HasAdminPermission(src, 'viewip') and RSGCore.Functions.GetIdentifier(id, 'ip') or nil,
        discordId = discordId,
        discordName = discordName,
        discordAvatarUrl = discordAvatarUrl,
        items = items,
    }
    for _, t in ipairs(moneyTypes) do info[t] = pd.money[t] end
    cb(info)
end)

-----------------------------------------------------------------------
-- kill / status effects / trolls (natives that only work on the target's
-- own client are relayed there; see client_playeractions.lua)
-----------------------------------------------------------------------
local relayActions = {
    { event = 'killplayer', action = 'kill', severity = 'medium', log = 'sv_log_killed_player' },
    { event = 'ragdollplayer', action = 'ragdoll', severity = 'low', log = 'sv_log_ragdolled_player' },
    { event = 'lightningplayer', action = 'lightning', severity = 'low', log = 'sv_log_struck_player_with_lightning' },
    { event = 'drainstaminaplayer', action = 'drainstamina', severity = 'low', log = 'sv_log_drained_player_stamina' },
    { event = 'drunkplayer', action = 'drunk', severity = 'low', log = 'sv_log_applied_drunk_effect_to_player' },
    { event = 'jumpscareplayer', action = 'jumpscare', severity = 'low', log = 'sv_log_jump_scared_player' },
    { event = 'horsebuckplayer', action = 'horsebuck', severity = 'low', log = 'sv_log_bucked_player_from_horse' },
    { event = 'hauntedplayer', action = 'haunted', severity = 'low', log = 'sv_log_applied_haunted_effect_to_player' },
    { event = 'everyoneattackplayer', action = 'everyoneattack', severity = 'medium', log = 'sv_log_made_everyone_attack_player' },
    { event = 'wildattack', action = 'wildattack', severity = 'medium', log = 'sv_log_triggered_wild_animal_attack_on_player' },
    { event = 'playerfire', action = 'setonfire', severity = 'medium', log = 'sv_log_set_player_on_fire' },
}

for _, def in ipairs(relayActions) do
    RegisterPlayerAction(def.event, def.action, true, function(src, target)
        TriggerClientEvent('rsg-adminmenu:client:' .. def.event, target)
        LogAdminAction('player_action', def.severity, src, locale(def.log), nil, GetPlayerName(target), target)
    end)
end

-- position is server-authoritative, so this is a direct coord bump
RegisterPlayerAction('toheavenplayer', 'toheaven', true, function(src, target)
    local ped = GetPlayerPed(target)
    local coords = GetEntityCoords(ped)
    SetEntityCoords(ped, coords.x, coords.y, coords.z + 300.0)
    LogAdminAction('player_action', 'low', src, locale('sv_log_launched_player_skyward'), nil, GetPlayerName(target), target)
end)

-- reuses rsg-lawman's cuff flow (it owns the toggle state and 'ishandcuffed' metadata)
RegisterPlayerAction('handcuffplayer', 'handcuff', true, function(src, target)
    TriggerClientEvent('rsg-lawman:client:getcuffed', target, src, false)
    LogAdminAction('player_action', 'low', src, locale('sv_log_handcuffed_uncuffed_player'), nil, GetPlayerName(target), target)
end)

-----------------------------------------------------------------------
-- warn player — logged to admin_player_history, no kick
-----------------------------------------------------------------------
local allowedSeverities = { low = true, medium = true, high = true }

RegisterPlayerAction('warnplayer', 'warn', true, function(src, target, reason, severity)
    reason = SanitizeText(reason, 255)
    if not reason then return NotifyPlayer(src, locale('sv_101'), locale('sv_reason_required'), 'error') end
    severity = allowedSeverities[severity] and severity or 'medium'
    local targetPlayer = RSGCore.Functions.GetPlayer(target)
    LogPlayerHistory(targetPlayer.PlayerData.citizenid, 'warn', reason, AdminDisplayName(src), nil, severity)
    NotifyPlayer(target, locale('sv_you_have_been_warned'), reason, 'error', 10000)
    LogAdminAction('player_action', severity, src, locale('sv_log_warned_player'), reason, GetPlayerName(target), target)
end)

-----------------------------------------------------------------------
-- set permission level (replaces rather than stacks; shares the Admins page path)
-----------------------------------------------------------------------
RegisterPlayerAction('setpermission', 'setpermission', true, function(src, target, level)
    local targetPlayer = RSGCore.Functions.GetPlayer(target)
    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname
    level = (type(level) == 'string' and level ~= '') and level or nil

    local ok, message = ChangeAdminRole(src, targetPlayer.PlayerData.citizenid, target, level, targetName)
    if not ok then
        return NotifyPlayer(src, locale('sv_101'), message, 'error')
    end

    local levelLabel = level and LabelForRole(level) or locale('sv_role_user')
    NotifyPlayer(src, locale('sv_permission_updated'), locale('sv_permission_set_to', levelLabel), 'success')
    LogAdminAction('admin_action', 'high', src, locale('sv_log_changed_player_permission_level'), locale('sv_log_new_level', levelLabel), targetName, target)
end)

-----------------------------------------------------------------------
-- set job (jobs live in the database; SetJob rejects unknown jobs/grades)
-----------------------------------------------------------------------
RegisterPlayerAction('setjob', 'setjob', true, function(src, target, job, grade)
    job = type(job) == 'string' and job:lower() or nil
    grade = math.floor(tonumber(grade) or 0)
    local targetPlayer = RSGCore.Functions.GetPlayer(target)
    if not job or not targetPlayer.Functions.SetJob(job, grade) then
        return NotifyPlayer(src, locale('sv_101'), locale('sv_invalid_job'), 'error')
    end
    LogAdminAction('player_action', 'medium', src, locale('sv_log_changed_player_job'), locale('sv_log_job_grade', job, tostring(grade)), GetPlayerName(target), target)
end)

-----------------------------------------------------------------------
-- set charinfo field (charinfo is free-form JSON, so new keys need no migration)
-----------------------------------------------------------------------
local charFieldLimits = { nickname = 50, firstname = 50, lastname = 50, age = 3, description = 500 }

RegisterPlayerAction('setcharfield', 'setcharfield', true, function(src, target, field, value)
    local limit = charFieldLimits[field]
    if not limit then return end
    value = SanitizeText(value, limit)
    if field == 'age' then value = tonumber(value) and math.floor(tonumber(value)) or nil end
    if (field == 'firstname' or field == 'lastname' or field == 'age') and not value then
        return NotifyPlayer(src, locale('sv_101'), locale('sv_invalid_value'), 'error')
    end

    local targetPlayer = RSGCore.Functions.GetPlayer(target)
    targetPlayer.PlayerData.charinfo[field] = value
    targetPlayer.Functions.UpdatePlayerData()
    targetPlayer.Functions.Save()
    LogAdminAction('player_action', 'medium', src, locale('sv_log_changed_player_character_field'), field .. ' = ' .. tostring(value), GetPlayerName(target), target)
end)

-----------------------------------------------------------------------
-- add/remove xp (stored in PlayerData.metadata.xp)
-----------------------------------------------------------------------
RegisterPlayerAction('adjustxp', 'xp', true, function(src, target, direction, amount)
    local delta = math.floor(tonumber(amount) or 0)
    if delta <= 0 then return NotifyPlayer(src, locale('sv_101'), locale('sv_invalid_value'), 'error') end
    local targetPlayer = RSGCore.Functions.GetPlayer(target)
    local current = tonumber(targetPlayer.Functions.GetMetaData('xp')) or 0
    local newXp = direction == 'remove' and math.max(0, current - delta) or current + delta
    targetPlayer.Functions.SetMetaData('xp', newXp)
    LogAdminAction('economy', 'low', src, locale('sv_log_adjusted_player_xp'), (direction == 'remove' and '-' or '+') .. delta .. ' (new: ' .. newXp .. ')', GetPlayerName(target), target)
end)

-----------------------------------------------------------------------
-- clear weapons / clear items
-----------------------------------------------------------------------
RegisterPlayerAction('clearweapons', 'clearweapons', true, function(src, target)
    local targetPlayer = RSGCore.Functions.GetPlayer(target)
    for _, item in pairs(targetPlayer.PlayerData.items or {}) do
        local itemDef = item and RSGCore.Shared.Items[item.name:lower()]
        if itemDef and itemDef.type == 'weapon' then
            exports['rsg-inventory']:RemoveItem(target, item.name, item.amount, item.slot, locale('sv_admin_cleared_weapons'))
        end
    end
    TriggerClientEvent('rsg-adminmenu:client:clearweapons', target)
    LogAdminAction('player_action', 'medium', src, locale('sv_log_cleared_player_weapons'), nil, GetPlayerName(target), target)
end)

RegisterPlayerAction('clearitems', 'clearitems', true, function(src, target)
    exports['rsg-inventory']:ClearInventory(target)
    LogAdminAction('player_action', 'medium', src, locale('sv_log_cleared_player_items'), nil, GetPlayerName(target), target)
end)

-----------------------------------------------------------------------
-- item catalog (for the "select item to add" picker) + per-slot removal
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getallitems', function(source, cb)
    if not HasAdminPermission(source, 'giveitem') then return cb({}) end

    local items = {}
    for name, item in pairs(RSGCore.Shared.Items) do
        if not MONEY_ITEMS[name] then
            items[#items + 1] = {
                name = name,
                label = item.label or name,
                image = item.image,
                type = item.type or 'item',
                weight = item.weight or 0,
                category = item.category,
            }
        end
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    cb(items)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:removeplayeritem', function(source, cb, data)
    local src = source
    if not HasAdminPermission(src, 'giveitem') then return cb({ success = false }) end
    data = type(data) == 'table' and data or {}
    local target = ResolveTarget(data.id)
    local amount = math.floor(tonumber(data.amount) or 0)
    local slot = tonumber(data.slot)
    if not target or type(data.item) ~= 'string' or amount < 1 or not slot then return cb({ success = false }) end
    if not CanActOn(src, target) then return cb({ success = false }) end

    local removed = exports['rsg-inventory']:RemoveItem(target, data.item, amount, slot, locale('sv_admin_removed_item'))
    if removed then
        LogAdminAction('player_action', 'medium', src, locale('sv_log_removed_item_from_player'), data.item .. ' x' .. amount, GetPlayerName(target), target)
    end
    cb({ success = removed and true or false })
end)

-----------------------------------------------------------------------
-- report command (any player)
-----------------------------------------------------------------------
RSGCore.Commands.Add('report', locale('sv_report_command_desc'), {}, false, function(source)
    TriggerClientEvent('rsg-adminmenu:client:openreportmenu', source)
end)

-----------------------------------------------------------------------
-- self tools: the server authorises and logs, the client applies the effect
-----------------------------------------------------------------------
local selfToolLogs = {
    godmode = 'sv_log_toggled_godmode',
    invisible = 'sv_log_toggled_invisible',
    playerblips = 'sv_log_toggled_player_blips',
    doorids = 'sv_log_toggled_door_ids',
    marker = 'sv_log_teleported_to_marker',
}

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:selftool', function(source, cb, data)
    local src = source
    local tool = type(data) == 'table' and data.tool or nil
    if not selfToolLogs[tool] then return cb({ success = false }) end
    if not HasAdminPermission(src, 'selftools') then return cb({ success = false }) end
    if tool == 'playerblips' and not Config.EnablePlayerBlips then return cb({ success = false }) end

    local details = data.enabled ~= nil and (data.enabled and locale('sv_on') or locale('sv_off')) or nil
    LogAdminAction('admin_action', 'low', src, locale(selfToolLogs[tool]), details, nil)
    cb({ success = true })
end)

-- self revive (server-side so rsg-medic's isdead metadata is cleared)
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:selfrevive', function(source, cb)
    local src = source
    if not HasAdminPermission(src, 'revive') then return cb({ success = false }) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then Player.Functions.SetMetaData('isdead', false) end
    TriggerClientEvent('rsg-medic:client:revive', src)
    LogAdminAction('player_action', 'low', src, locale('sv_log_revived_player'), nil, GetPlayerName(src), src)
    cb({ success = true })
end)
