local RSGCore = exports['rsg-core']:GetCoreObject()

-----------------------------------------------------------------------
-- permissions: the minimum role each action needs. These are checked on the
-- server for every request; the roleFlags sent to the UI only hide buttons.
-- 'helper' = all staff, 'mod' = moderator+, 'admin' = admin+.
-----------------------------------------------------------------------
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
    ['worldtools'] = 'mod',
    -- rsg-core's default server.cfg has no headadmin group, so god/developer
    -- are listed too (matches the UI's fullAccess flag)
    ['serversettings'] = { 'god', 'headadmin', 'developer' },
}

local PERMANENT_BAN = 2524608000 -- 01/01/2050, treated as "permanent"
local MAX_ITEM_AMOUNT = 1000
local MAX_TEXT = 255

-----------------------------------------------------------------------
-- shared helpers (global so the other server files can use them)
-----------------------------------------------------------------------
function HasAdminPermission(src, key)
    local perm = permissions[key]
    if not perm then return false end
    return RSGCore.Functions.HasPermission(src, perm) or IsPlayerAceAllowed(src, 'god')
end

-- server-side rsg-core notify
function Notify(src, title, description, notifyType, duration)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title,
        description = description,
        type = notifyType or 'inform',
        duration = duration or 5000,
    })
end

-- trims a client string and caps its length; returns nil when empty
function CleanText(value, maxLen)
    if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
    value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' then return nil end
    return value:sub(1, maxLen or MAX_TEXT)
end

-- resolves the { id = x } table (or bare id) the NUI sends into a live server id
local function TargetId(player)
    local id = tonumber(type(player) == 'table' and player.id or player)
    if not id or not GetPlayerName(id) then return nil end
    return id
end

local function CharName(Player)
    local info = Player and Player.PlayerData.charinfo or {}
    local name = ((info.firstname or '') .. ' ' .. (info.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return name
end

-- a client fired a staff-only event without the role for it
local function DenyAndBan(src, action)
    local Player = RSGCore.Functions.GetPlayer(src)
    local name = Player and CharName(Player) or GetPlayerName(src) or tostring(src)
    local citizenid = Player and Player.PlayerData.citizenid or 'n/a'
    TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red',
        ('%s %s %s %s (%s)'):format(name, locale('sv_h'), citizenid, locale('sv_ban_k'), tostring(action)), true)
    LogAdminAction('security', 'high', src, locale('sv_log_unauthorized_action_attempt_auto_banned'),
        locale('sv_log_citizen_id', citizenid) .. ' | ' .. tostring(action), name)
    exports['rsg-core']:ExploitBan(src, 'rsg-adminmenu: ' .. tostring(action))
end

-- permission gate for net events: bans on failure
local function Authorise(src, key)
    if HasAdminPermission(src, key) then return true end
    DenyAndBan(src, key)
    return false
end

-- registers a staff action that targets an online player. `fn(src, targetId, ...)`
-- only runs once the caller is authorised and the target is a valid player.
local function RegisterTargetAction(eventName, permKey, fn)
    RegisterNetEvent('rsg-adminmenu:server:' .. eventName, function(player, ...)
        local src = source
        if not Authorise(src, permKey) then return end
        local targetId = TargetId(player)
        if not targetId then
            Notify(src, locale('sv_101'), locale('sv_invalid_input'), 'error')
            return
        end
        fn(src, targetId, ...)
    end)
end

-- "tell a client to do X, then log it" actions. toCaller = run on the admin's
-- client (with the target id as argument) instead of the target's client.
local function RegisterRelayAction(eventName, permKey, clientEvent, severity, logKey, toCaller)
    RegisterTargetAction(eventName, permKey, function(src, targetId)
        if toCaller then
            TriggerClientEvent(clientEvent, src, targetId)
        else
            TriggerClientEvent(clientEvent, targetId)
        end
        LogAdminAction('player_action', severity, src, locale(logKey), nil, GetPlayerName(targetId), targetId)
    end)
end

-----------------------------------------------------------------------
-- players list (also feeds the player-blips toggle)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getplayers', function(source, cb)
    if not HasAdminPermission(source, 'adminmenu') then return cb({}) end
    local players = {}
    for _, id in pairs(RSGCore.Functions.GetPlayers()) do
        local Player = RSGCore.Functions.GetPlayer(id)
        if Player then
            players[#players + 1] = {
                name = CharName(Player) .. ' | (' .. (GetPlayerName(id) or '?') .. ')',
                id = id,
                coords = GetEntityCoords(GetPlayerPed(id)),
                citizenid = Player.PlayerData.citizenid,
            }
        end
    end
    table.sort(players, function(a, b) return a.id < b.id end)
    cb(players)
end)

-----------------------------------------------------------------------
-- Discord identity (name/avatar) lookups, cached
-----------------------------------------------------------------------
local discordNameCache = {}

local function BotToken()
    local token = Config.DiscordBot and Config.DiscordBot.Token
    if not token or token == '' or token == 'TOKEN HERE' or token == 'YOUR_DISCORD_BOT_TOKEN_HERE' then return nil end
    return token
end

-- synchronous cache read; only returns a name once ResolveDiscordName has warmed it
function GetCachedDiscordIdentity(source)
    local discordId = RSGCore.Functions.GetIdentifier(source, 'discord')
    if not discordId then return nil, nil, nil end
    discordId = discordId:gsub('discord:', '')
    local cached = discordNameCache[discordId]
    if not cached then return discordId, nil, nil end
    return discordId, cached.name, cached.avatarUrl
end

-- "By: ..." name for an acting admin: Discord name if known, else Rockstar name
function AdminDisplayName(source)
    local _, discordName = GetCachedDiscordIdentity(source)
    return discordName or GetPlayerName(source)
end

local function AvatarUrl(userId, avatar)
    if not avatar then return nil end
    local ext = avatar:sub(1, 2) == 'a_' and 'gif' or 'png'
    return ('https://cdn.discordapp.com/avatars/%s/%s.%s?size=128'):format(userId, avatar, ext)
end

function ResolveDiscordName(discordId, cb)
    if not discordId or discordId == '' then return cb(nil, nil) end
    local cached = discordNameCache[discordId]
    if cached then return cb(cached.name, cached.avatarUrl) end
    local token = BotToken()
    if not token then return cb(nil, nil) end

    PerformHttpRequest('https://discord.com/api/v10/users/' .. discordId, function(statusCode, resultData)
        if statusCode ~= 200 or not resultData then return cb(nil, nil) end
        local ok, decoded = pcall(json.decode, resultData)
        if not ok or not decoded then return cb(nil, nil) end
        local name = decoded.global_name or decoded.username
        local avatarUrl = AvatarUrl(discordId, decoded.avatar)
        if name then discordNameCache[discordId] = { name = name, avatarUrl = avatarUrl } end
        cb(name, avatarUrl)
    end, 'GET', '', { ['Authorization'] = 'Bot ' .. token, ['Content-Type'] = 'application/json' })
end

-- warm the cache on join, throttled (~6/s) so a reconnect burst after a
-- restart can't trip Discord's rate limit
local discordWarmQueue, discordWarmRunning = {}, false

local function ProcessDiscordWarmQueue()
    if discordWarmRunning then return end
    discordWarmRunning = true
    CreateThread(function()
        while #discordWarmQueue > 0 do
            local discordId = table.remove(discordWarmQueue, 1)
            if not discordNameCache[discordId] then ResolveDiscordName(discordId, function() end) end
            Wait(150)
        end
        discordWarmRunning = false
    end)
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if not BotToken() then return end
    local discordId = RSGCore.Functions.GetIdentifier(Player.PlayerData.source, 'discord')
    if discordId then
        discordWarmQueue[#discordWarmQueue + 1] = discordId:gsub('discord:', '')
        ProcessDiscordWarmQueue()
    end
end)

-- the bot's own avatar, used as the sidebar logo
local botIdentityCache = nil

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getbotlogo', function(source, cb)
    if not HasAdminPermission(source, 'adminmenu') then return cb({}) end
    if botIdentityCache then return cb(botIdentityCache) end
    local token = BotToken()
    if not token then return cb({}) end

    PerformHttpRequest('https://discord.com/api/v10/users/@me', function(statusCode, resultData)
        local ok, decoded = false, nil
        if statusCode == 200 and resultData then ok, decoded = pcall(json.decode, resultData) end
        if not ok or not decoded then
            botIdentityCache = {}
        else
            botIdentityCache = { logoUrl = AvatarUrl(decoded.id, decoded.avatar), name = decoded.username }
        end
        cb(botIdentityCache)
    end, 'GET', '', { ['Authorization'] = 'Bot ' .. token, ['Content-Type'] = 'application/json' })
end)

-----------------------------------------------------------------------
-- all registered players (online + offline) for the Players page
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getallplayersmanaged', function(source, cb)
    if not HasAdminPermission(source, 'playerinfo') then return cb({}) end

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

                local online = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)
                -- DB money is only as fresh as the last autosave; prefer live data
                local liveMoney = (online and online.PlayerData.money) or money
                local moneyTotal = 0
                for _, v in pairs(liveMoney) do
                    if type(v) == 'number' then moneyTotal = moneyTotal + v end
                end

                local discordId, discordName, discordAvatarUrl
                if online then
                    discordId, discordName, discordAvatarUrl = GetCachedDiscordIdentity(online.PlayerData.source)
                end

                local ban = row.license and banByLicense[row.license] or nil
                result[#result + 1] = {
                    citizenid = row.citizenid,
                    serverId = online and online.PlayerData.source or nil,
                    name = (charinfo.firstname or '?') .. ' ' .. (charinfo.lastname or ''),
                    accountName = row.name or '',
                    job = online and online.PlayerData.job.label or (job.label or locale('sv_unemployed')),
                    money = moneyTotal,
                    playtimeMinutes = row.minutes or 0,
                    lastSeen = row.last_seen,
                    online = online ~= nil,
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

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:unbanplayer', function(source, cb, data)
    local src = source
    local banId = tonumber(type(data) == 'table' and data.banId)
    if not HasAdminPermission(src, 'ban') or not banId then return cb({ success = false }) end

    MySQL.update('DELETE FROM bans WHERE id = ?', { banId }, function(affected)
        local success = (affected or 0) > 0
        if success then
            LogAdminAction('player_action', 'medium', src, locale('sv_log_unbanned_player'), locale('sv_log_ban_id', tostring(banId)), nil)
        end
        cb({ success = success })
    end)
end)

-----------------------------------------------------------------------
-- /adminmenu
-----------------------------------------------------------------------
RSGCore.Commands.Add('adminmenu', locale('sv_100'), {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not HasAdminPermission(src, 'adminmenu') then
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_d'), 'red',
            CharName(Player) .. ' ' .. locale('sv_e') .. ' ' .. Player.PlayerData.citizenid .. ' ' .. locale('sv_f'), true)
        Notify(src, locale('sv_101'), locale('sv_102'), 'error')
        return
    end

    local discordId = RSGCore.Functions.GetIdentifier(src, 'discord')
    if discordId then discordId = discordId:gsub('discord:', '') end

    local isGod = IsPlayerAceAllowed(src, 'god')
    local canManageHistory = CanManageHistory(src)
    -- UI-only flags; the permissions table above is the real gate
    local roleFlags = {
        canManageHistory = canManageHistory,
        canManageAdmins = canManageHistory,
        atLeastMod = isGod or RSGCore.Functions.HasPermission(src, 'mod'),
        atLeastAdmin = isGod or RSGCore.Functions.HasPermission(src, 'admin'),
        fullAccess = isGod or RSGCore.Functions.HasPermission(src, { 'headadmin', 'developer' }),
    }
    ResolveDiscordName(discordId, function(discordName, discordAvatar)
        TriggerClientEvent('rsg-adminmenu:client:openadminmenu', src, { discordName = discordName, discordAvatar = discordAvatar, roleFlags = roleFlags })
    end)
end)

-----------------------------------------------------------------------
-- core player actions
-----------------------------------------------------------------------
RegisterTargetAction('playerrevive', 'revive', function(src, targetId)
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if Target then Target.Functions.SetMetaData('isdead', false) end
    TriggerClientEvent('rsg-medic:client:revive', targetId)
    LogAdminAction('player_action', 'low', src, locale('sv_log_revived_player'), nil, GetPlayerName(targetId), targetId)
end)

RegisterNetEvent('rsg-adminmenu:server:selfrevive', function()
    local src = source
    if not Authorise(src, 'revive') then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then Player.Functions.SetMetaData('isdead', false) end
    TriggerClientEvent('rsg-medic:client:revive', src)
    LogAdminAction('player_action', 'low', src, locale('sv_log_revived_player'), nil, GetPlayerName(src), src)
end)

RegisterTargetAction('openinventory', 'inventory', function(src, targetId)
    exports['rsg-inventory']:OpenInventoryById(src, targetId)
    LogAdminAction('player_action', 'low', src, locale('sv_log_opened_player_inventory'), nil, GetPlayerName(targetId), targetId)
end)

RegisterTargetAction('kickplayer', 'kick', function(src, targetId, reason)
    reason = CleanText(reason) or locale('sv_no_reason')
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if Target then
        LogPlayerHistory(Target.PlayerData.citizenid, 'kick', reason, AdminDisplayName(src), nil)
    end
    local targetName = GetPlayerName(targetId)
    TriggerEvent('rsg-log:server:CreateLog', 'bans', locale('sv_kicked'), 'red',
        locale('sv_kicked_a', targetName, GetPlayerName(src), reason), true)
    LogAdminAction('player_action', 'medium', src, locale('sv_log_kicked_player'), reason, targetName, targetId)
    DropPlayer(targetId, locale('sv_103') .. ':\n' .. reason .. '\n\n' .. locale('sv_104') .. (RSGCore.Config.Server.Discord or ''))
end)

RegisterTargetAction('banplayer', 'ban', function(src, targetId, duration, reason)
    duration = tonumber(duration)
    if not duration or duration <= 0 then
        Notify(src, locale('sv_101'), locale('sv_invalid_input'), 'error')
        return
    end
    duration = math.floor(duration)
    reason = CleanText(reason) or locale('sv_no_reason')
    local banTime = math.min(os.time() + duration, PERMANENT_BAN)
    local targetName = GetPlayerName(targetId)

    local Target = RSGCore.Functions.GetPlayer(targetId)
    if Target then
        LogPlayerHistory(Target.PlayerData.citizenid, 'ban', reason, AdminDisplayName(src), duration)
    end
    MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        targetName,
        RSGCore.Functions.GetIdentifier(targetId, 'license'),
        RSGCore.Functions.GetIdentifier(targetId, 'discord'),
        RSGCore.Functions.GetIdentifier(targetId, 'ip'),
        reason,
        banTime,
        GetPlayerName(src),
    })
    -- name and reason go through {0}/{1} args so chat escapes them
    TriggerClientEvent('chat:addMessage', -1, {
        template = "<div class='chat-message server'><strong>" .. locale('sv_ban') .. ' | {0} ' .. locale('sv_ban_a') .. ':</strong> {1}</div>',
        args = { targetName, reason },
    })
    TriggerEvent('rsg-log:server:CreateLog', 'bans', locale('sv_a'), 'red', locale('sv_b', targetName, GetPlayerName(src), reason), true)
    LogAdminAction('player_action', 'high', src, locale('sv_log_banned_player'), locale('sv_log_ban_details', reason, tostring(duration)), targetName, targetId)

    local discord = RSGCore.Config.Server.Discord or ''
    if banTime >= PERMANENT_BAN then
        DropPlayer(targetId, locale('sv_106') .. '\n' .. reason .. '\n\n' .. locale('sv_107') .. '\n' .. locale('sv_108') .. discord)
    else
        DropPlayer(targetId, locale('sv_106') .. '\n' .. reason .. '\n\n' .. locale('sv_109') .. os.date('%d/%m/%Y %H:%M', banTime) .. '\n' .. locale('sv_110') .. discord)
    end
end)

RegisterTargetAction('gotoplayer', 'goto', function(src, targetId)
    SetEntityCoords(GetPlayerPed(src), GetEntityCoords(GetPlayerPed(targetId)))
    LogAdminAction('player_action', 'low', src, locale('sv_log_teleported_to_player'), nil, GetPlayerName(targetId), targetId)
end)

RegisterTargetAction('bringplayer', 'bring', function(src, targetId)
    SetEntityCoords(GetPlayerPed(targetId), GetEntityCoords(GetPlayerPed(src)))
    LogAdminAction('player_action', 'low', src, locale('sv_log_brought_player_to_self'), nil, GetPlayerName(targetId), targetId)
end)

local frozenPlayers = {}
AddEventHandler('playerDropped', function() frozenPlayers[source] = nil end)

RegisterTargetAction('freezeplayer', 'freeze', function(src, targetId)
    local targetName = GetPlayerName(targetId)
    local freeze = not frozenPlayers[targetId]
    frozenPlayers[targetId] = freeze or nil
    FreezeEntityPosition(GetPlayerPed(targetId), freeze)
    if freeze then
        Notify(src, locale('sv_111'), locale('sv_112') .. targetName)
        LogAdminAction('player_action', 'low', src, locale('sv_log_froze_player'), nil, targetName, targetId)
    else
        Notify(src, locale('sv_113'), locale('sv_114') .. targetName)
        LogAdminAction('player_action', 'low', src, locale('sv_log_unfroze_player'), nil, targetName, targetId)
    end
end)

RegisterTargetAction('spectateplayer', 'spectate', function(src, targetId)
    if targetId == src then return end
    TriggerClientEvent('rsg-adminmenu:client:spectateplayer', src, targetId, GetEntityCoords(GetPlayerPed(targetId)))
    LogAdminAction('player_action', 'low', src, locale('sv_log_started_spectating_player'), nil, GetPlayerName(targetId), targetId)
end)

RegisterTargetAction('giveitem', 'giveitem', function(src, targetId, item, amount)
    item = type(item) == 'string' and item:lower() or nil
    amount = math.floor(tonumber(amount) or 0)
    if not item or not RSGCore.Shared.Items[item] then
        Notify(src, locale('sv_101'), locale('sv_invalid_item'), 'error')
        return
    end
    if amount < 1 or amount > MAX_ITEM_AMOUNT then
        Notify(src, locale('sv_101'), locale('sv_invalid_input'), 'error')
        return
    end
    if not exports['rsg-inventory']:CanAddItem(targetId, item, amount) then
        Notify(src, locale('sv_101'), locale('sv_target_inventory_full'), 'error')
        return
    end
    if exports['rsg-inventory']:AddItem(targetId, item, amount, nil, nil, 'rsg-adminmenu:giveitem') then
        Notify(src, locale('sv_135'), locale('sv_136'), 'success')
        LogAdminAction('player_action', 'medium', src, locale('sv_log_gave_item_to_player'), item .. ' x' .. amount, GetPlayerName(targetId), targetId)
    end
end)

-----------------------------------------------------------------------
-- player info (manage modal)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getplayerinfo', function(source, cb, player)
    if not HasAdminPermission(source, 'playerinfo') then return cb(nil) end
    local id = TargetId(player)
    local Target = id and RSGCore.Functions.GetPlayer(id)
    if not Target then return cb(nil) end

    local pd = Target.PlayerData
    local discordId, discordName, discordAvatarUrl = GetCachedDiscordIdentity(id)

    local availablePermissions = {}
    for _, level in ipairs(RSGCore.Config.Server.Permissions) do
        availablePermissions[#availablePermissions + 1] = { value = level, label = LabelForRole(level) }
    end

    local items = {}
    for _, item in pairs(pd.items or {}) do
        if item and item.name then
            local def = RSGCore.Shared.Items[item.name:lower()]
            items[#items + 1] = {
                slot = item.slot,
                name = item.name,
                label = (def and def.label) or item.name,
                image = def and def.image or nil,
                amount = item.amount,
                weight = (def and def.weight) or 0,
            }
        end
    end

    local role = GetPlayerRole(id)
    cb({
        firstname = pd.charinfo.firstname,
        lastname = pd.charinfo.lastname,
        job = pd.job.label,
        grade = pd.job.grade.level,
        jobGradeName = pd.job.grade.name,
        cash = pd.money.cash or 0,
        bloodmoney = pd.money.bloodmoney or 0,
        bank = pd.money.bank or 0,
        gold = pd.money.gold or 0,
        citizenid = pd.citizenid,
        serverid = id,
        role = role,
        roleLabel = LabelForRole(role),
        availablePermissions = availablePermissions,
        ping = GetPlayerPing(id),
        steamHex = RSGCore.Functions.GetIdentifier(id, 'steam'),
        ip = RSGCore.Functions.GetIdentifier(id, 'ip'),
        discordId = discordId,
        discordName = discordName,
        discordAvatarUrl = discordAvatarUrl,
        items = items,
    })
end)

-----------------------------------------------------------------------
-- status-effect / troll actions (natives that only work on the target's
-- own client are relayed via client_playeractions.lua)
-----------------------------------------------------------------------
RegisterTargetAction('healplayer', 'heal', function(src, targetId)
    TriggerClientEvent('rsg-medic:client:heal', targetId, -1)
    LogAdminAction('player_action', 'low', src, locale('sv_log_healed_player'), nil, GetPlayerName(targetId), targetId)
end)

RegisterRelayAction('killplayer', 'kill', 'rsg-adminmenu:client:killplayer', 'medium', 'sv_log_killed_player')
RegisterRelayAction('ragdollplayer', 'ragdoll', 'rsg-adminmenu:client:ragdollplayer', 'low', 'sv_log_ragdolled_player')
RegisterRelayAction('lightningplayer', 'lightning', 'rsg-adminmenu:client:lightningplayer', 'low', 'sv_log_struck_player_with_lightning')
RegisterRelayAction('drainstaminaplayer', 'drainstamina', 'rsg-adminmenu:client:drainstaminaplayer', 'low', 'sv_log_drained_player_stamina')
RegisterRelayAction('drunkplayer', 'drunk', 'rsg-adminmenu:client:drunkplayer', 'low', 'sv_log_applied_drunk_effect_to_player')
RegisterRelayAction('jumpscareplayer', 'jumpscare', 'rsg-adminmenu:client:jumpscareplayer', 'low', 'sv_log_jump_scared_player')
RegisterRelayAction('horsebuckplayer', 'horsebuck', 'rsg-adminmenu:client:horsebuckplayer', 'low', 'sv_log_bucked_player_from_horse')
RegisterRelayAction('hauntedplayer', 'haunted', 'rsg-adminmenu:client:hauntedplayer', 'low', 'sv_log_applied_haunted_effect_to_player')
RegisterRelayAction('everyoneattackplayer', 'everyoneattack', 'rsg-adminmenu:client:everyoneattackplayer', 'medium', 'sv_log_made_everyone_attack_player')
-- these two run on the admin's client (it spawns the animal / starts the fire on the target ped)
RegisterRelayAction('wildattack', 'wildattack', 'rsg-adminmenu:client:wildattack', 'medium', 'sv_log_triggered_wild_animal_attack_on_player', true)
RegisterRelayAction('playerfire', 'setonfire', 'rsg-adminmenu:client:playerfire', 'medium', 'sv_log_set_player_on_fire', true)

RegisterTargetAction('toheavenplayer', 'toheaven', function(src, targetId)
    local ped = GetPlayerPed(targetId)
    local coords = GetEntityCoords(ped)
    SetEntityCoords(ped, coords.x, coords.y, coords.z + 300.0)
    LogAdminAction('player_action', 'low', src, locale('sv_log_launched_player_skyward'), nil, GetPlayerName(targetId), targetId)
end)

-- reuses rsg-lawman's cuff flow (it owns the toggle + ishandcuffed metadata)
RegisterTargetAction('handcuffplayer', 'handcuff', function(src, targetId)
    TriggerClientEvent('rsg-lawman:client:getcuffed', targetId, src, false)
    LogAdminAction('player_action', 'low', src, locale('sv_log_handcuffed_uncuffed_player'), nil, GetPlayerName(targetId), targetId)
end)

-----------------------------------------------------------------------
-- moderation
-----------------------------------------------------------------------
local allowedSeverities = { low = true, medium = true, high = true }

RegisterTargetAction('warnplayer', 'warn', function(src, targetId, reason, severity)
    local Target = RSGCore.Functions.GetPlayer(targetId)
    reason = CleanText(reason)
    if not Target or not reason then return end
    severity = allowedSeverities[severity] and severity or 'medium'
    LogPlayerHistory(Target.PlayerData.citizenid, 'warn', reason, AdminDisplayName(src), nil, severity)
    Notify(targetId, locale('sv_you_have_been_warned'), reason, 'error', 10000)
    LogAdminAction('player_action', severity, src, locale('sv_log_warned_player'), reason, GetPlayerName(targetId), targetId)
end)

-- replaces (doesn't stack) the target's role
RegisterTargetAction('setpermission', 'setpermission', function(src, targetId, level)
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then return end
    level = (type(level) == 'string' and level ~= '') and level or nil

    -- can't touch someone at/above your own role, or hand out a role at/above it
    if not CanManageRole(src, GetPlayerRole(targetId)) or (level and not CanManageRole(src, level)) then
        Notify(src, locale('sv_101'), locale('sv_role_too_high'), 'error')
        return
    end

    local admin = RSGCore.Functions.GetPlayer(src)
    local targetName = CharName(Target)
    if level then
        if not SetAdminRole(Target.PlayerData.citizenid, targetId, level, CharName(admin), RSGCore.Functions.GetIdentifier(targetId, 'discord'), targetName) then
            Notify(src, locale('sv_101'), locale('sv_invalid_role'), 'error')
            return
        end
    else
        RemoveAdminRole(Target.PlayerData.citizenid, targetId)
    end

    local levelLabel = level and LabelForRole(level) or locale('sv_role_user')
    Notify(src, locale('sv_permission_updated'), locale('sv_permission_set_to', levelLabel), 'success')
    LogAdminAction('admin_action', 'high', src, locale('sv_log_changed_player_permission_level'), locale('sv_log_new_level', levelLabel), targetName, targetId)
end)

-----------------------------------------------------------------------
-- character / job / xp
-----------------------------------------------------------------------
RegisterTargetAction('setjob', 'setjob', function(src, targetId, job, grade)
    local Target = RSGCore.Functions.GetPlayer(targetId)
    job = type(job) == 'string' and job:lower() or nil
    grade = math.floor(tonumber(grade) or 0)
    if not Target or not job then return end

    -- multi-job lives in rsg-core: make sure the job is held, then make it active
    exports['rsg-core']:AddPlayerJob(targetId, job, grade, true)
    if not Target.Functions.SetJob(job, grade) then
        Notify(src, locale('sv_101'), locale('sv_job_set_failed'), 'error')
        return
    end
    LogAdminAction('player_action', 'medium', src, locale('sv_log_changed_player_job'), locale('sv_log_job_grade', job, tostring(grade)), GetPlayerName(targetId), targetId)
end)

-- charinfo is free-form JSON, so these keys need no migration (value = max length)
local allowedCharFields = { nickname = 50, firstname = 50, lastname = 50, age = 3, description = 255 }

RegisterTargetAction('setcharfield', 'setcharfield', function(src, targetId, field, value)
    local maxLen = allowedCharFields[field]
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not maxLen or not Target then return end
    value = CleanText(value, maxLen)
    if field == 'age' then value = tonumber(value) and math.floor(tonumber(value)) or nil end
    if (field == 'firstname' or field == 'lastname') and not value then
        Notify(src, locale('sv_101'), locale('sv_invalid_input'), 'error')
        return
    end

    Target.PlayerData.charinfo[field] = value
    Target.Functions.SetPlayerData('charinfo', Target.PlayerData.charinfo)
    Target.Functions.Save()
    LogAdminAction('player_action', 'medium', src, locale('sv_log_changed_player_character_field'), field .. ' = ' .. tostring(value), GetPlayerName(targetId), targetId)
end)

-- no levelling system in rsg-core: stored as metadata.xp
RegisterTargetAction('adjustxp', 'xp', function(src, targetId, direction, amount)
    local Target = RSGCore.Functions.GetPlayer(targetId)
    local delta = math.floor(tonumber(amount) or 0)
    if not Target or delta <= 0 or delta > 1000000 then
        Notify(src, locale('sv_101'), locale('sv_invalid_input'), 'error')
        return
    end
    local current = tonumber(Target.Functions.GetMetaData('xp')) or 0
    local newXp = direction == 'remove' and math.max(0, current - delta) or current + delta
    Target.Functions.SetMetaData('xp', newXp)
    LogAdminAction('economy', 'low', src, locale('sv_log_adjusted_player_xp'),
        (direction == 'remove' and '-' or '+') .. delta .. ' (new: ' .. newXp .. ')', GetPlayerName(targetId), targetId)
end)

-----------------------------------------------------------------------
-- clear weapons / items
-----------------------------------------------------------------------
RegisterTargetAction('clearweapons', 'clearweapons', function(src, targetId)
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then return end
    for _, item in pairs(Target.PlayerData.items or {}) do
        local def = item and item.name and RSGCore.Shared.Items[item.name:lower()]
        if def and def.type == 'weapon' then
            exports['rsg-inventory']:RemoveItem(targetId, item.name, item.amount, item.slot, 'rsg-adminmenu:clearweapons')
        end
    end
    TriggerClientEvent('rsg-adminmenu:client:clearweapons', targetId)
    LogAdminAction('player_action', 'medium', src, locale('sv_log_cleared_player_weapons'), nil, GetPlayerName(targetId), targetId)
end)

RegisterTargetAction('clearitems', 'clearitems', function(src, targetId)
    exports['rsg-inventory']:ClearInventory(targetId)
    LogAdminAction('player_action', 'medium', src, locale('sv_log_cleared_player_items'), nil, GetPlayerName(targetId), targetId)
end)

-----------------------------------------------------------------------
-- item catalogue (give-item picker) + per-slot removal
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getallitems', function(source, cb)
    if not HasAdminPermission(source, 'giveitem') then return cb({}) end
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
    if not HasAdminPermission(src, 'giveitem') or type(data) ~= 'table' then return cb({ success = false }) end
    local targetId = TargetId(data.id)
    local amount = math.floor(tonumber(data.amount) or 0)
    if not targetId or type(data.item) ~= 'string' or amount < 1 then return cb({ success = false }) end

    local removed = exports['rsg-inventory']:RemoveItem(targetId, data.item, amount, tonumber(data.slot), 'rsg-adminmenu:removeitem')
    if removed then
        LogAdminAction('player_action', 'medium', src, locale('sv_log_removed_item_from_player'), data.item .. ' x' .. amount, GetPlayerName(targetId), targetId)
    end
    cb({ success = removed and true or false })
end)

-----------------------------------------------------------------------
-- /report (any player)
-----------------------------------------------------------------------
RSGCore.Commands.Add('report', locale('sv_report_command_desc'), {}, false, function(source)
    TriggerClientEvent('rsg-adminmenu:client:openreportmenu', source)
end)
