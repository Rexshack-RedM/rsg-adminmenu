local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

permissions = {
    ['adminmenu'] = 'admin',
    ['revive'] = 'admin',
    ['inventory'] = 'admin',
    ['kick'] = 'admin',
    ['ban'] = 'admin',
    ['goto'] = 'admin',
    ['bring'] = 'admin',
    ['freeze'] = 'admin',
    ['spectate'] = 'admin',
    ['wildattack'] = 'admin',
    ['setonfire'] = 'admin',
    ['giveitem'] = 'admin',
    ['playerinfo'] = 'admin',
    ['givemoney'] = 'admin',
}

-----------------------------------------------------------------------
-- get players function
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getplayers', function(source, cb)
    local src = source
    local players = {}
    for k,v in pairs(RSGCore.Functions.GetPlayers()) do
        local target = GetPlayerPed(v)
        local ped = RSGCore.Functions.GetPlayer(v)
        players[#players + 1] = {
        name = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname .. ' | (' .. GetPlayerName(v) .. ')',
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
    MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        GetPlayerName(src),
        RSGCore.Functions.GetIdentifier(src, 'license'),
        RSGCore.Functions.GetIdentifier(src, 'discord'),
        RSGCore.Functions.GetIdentifier(src, 'ip'),
        'system banned you',
        2524608000,
        'rsg-adminmenu'
    })
    TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_a'), 'red', string.format(locale('sv_b'), GetPlayerName(src), 'rsg-adminmenu', locale('sv_c')), true)
    DropPlayer(src, locale('sv_105'))
end

-----------------------------------------------------------------------
-- admin menu command
-----------------------------------------------------------------------
RSGCore.Commands.Add('adminmenu', locale('sv_100'), {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['adminmenu']) or IsPlayerAceAllowed(src, 'command')  then
        TriggerClientEvent('rsg-adminmenu:client:openadminmenu', src)
   else
        --BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_d'), 'red', firstname .. ' ' .. lastname .. ' ' .. locale('sv_e') .. ' '..citizenid..' '.. locale('sv_f'), true)
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
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

    if RSGCore.Functions.HasPermission(src, permissions['revive']) or IsPlayerAceAllowed(src, 'command')  then
        TriggerClientEvent('rsg-medic:client:adminRevive', player.id)
    else
        BanPlayer(src)
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red', firstname..' '..lastname..' ' .. locale('sv_h') .. ' '..citizenid..' '.. locale('sv_i'), true)
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

    if RSGCore.Functions.HasPermission(src, permissions['inventory']) or IsPlayerAceAllowed(src, 'command') then
        exports['rsg-inventory']:OpenInventoryById(src, tonumber(player.id))
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red', firstname..' '..lastname..' ' .. locale('sv_h') .. ' '..citizenid..' '.. locale('sv_j'), true)
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
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

    if RSGCore.Functions.HasPermission(src, permissions['kick']) or IsPlayerAceAllowed(src, 'command')  then
        TriggerEvent('rsg-log:server:CreateLog', 'bans', locale('sv_kicked'), 'red', string.format(locale('sv_kicked_a'), GetPlayerName(player), GetPlayerName(src), reason), true)
        DropPlayer(player, locale('sv_103') .. ':\n' .. reason .. '\n\n' .. locale('sv_104') .. RSGCore.Config.Server.Discord)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red', firstname..' '..lastname..' ' .. locale('sv_h') .. ' '..citizenid..' '.. locale('sv_kicked_b'), true)
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

RegisterNetEvent('rsg-adminmenu:server:banplayer', function(player, time, reason)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['ban']) or IsPlayerAceAllowed(src, 'command') then
        time = tonumber(time)
        local banTime = tonumber(os.time() + time)
        if banTime > 2524608000 then
            banTime = 2524608000
        end
        local timeTable = os.date('*t', banTime)
        MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            GetPlayerName(player),
            RSGCore.Functions.GetIdentifier(player, 'license'),
            RSGCore.Functions.GetIdentifier(player, 'discord'),
            RSGCore.Functions.GetIdentifier(player, 'ip'),
            reason,
            banTime,
            GetPlayerName(src)
        })
        TriggerClientEvent('chat:addMessage', -1, {
            template = "<div class=chat-message server'><strong>".. locale('sv_ban') .. " | {0}" .. locale('sv_ban_a') .. ":</strong> {1}</div>",
            args = {GetPlayerName(player), reason}
        })
        TriggerEvent('rsg-log:server:CreateLog', 'bans', locale('sv_a'), 'red', string.format(locale('sv_b'), GetPlayerName(player), GetPlayerName(src), reason), true)
        if banTime >= 2524608000 then
            DropPlayer(player, locale('sv_106') .. '\n' .. reason .. '\n\n'..locale('sv_107')..'\n'..locale('sv_108') .. RSGCore.Config.Server.Discord)
        else
            DropPlayer(player, locale('sv_106') .. '\n' .. reason .. '\n\n'..locale('sv_109') .. timeTable['day'] .. '/' .. timeTable['month'] .. '/' .. timeTable['year'] .. ' ' .. timeTable['hour'] .. ':' .. timeTable['min'] .. '\n' ..locale('sv_110') .. RSGCore.Config.Server.Discord)
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

    if RSGCore.Functions.HasPermission(src, permissions['goto']) or IsPlayerAceAllowed(src, 'command') then
        local admin = GetPlayerPed(src)
        local coords = GetEntityCoords(GetPlayerPed(player.id))
        SetEntityCoords(admin, coords)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red', firstname..' '..lastname..' ' .. locale('sv_h') .. ' '..citizenid..' ' .. locale('sv_ban_c'), true)
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
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

    if RSGCore.Functions.HasPermission(src, permissions['bring']) or IsPlayerAceAllowed(src, 'command') then
        local admin = GetPlayerPed(src)
        local coords = GetEntityCoords(admin)
        local target = GetPlayerPed(player.id)
        SetEntityCoords(target, coords)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red', firstname..' '..lastname..' ' .. locale('sv_h') .. ' '..citizenid..' ' .. locale('sv_ban_d'), true)
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- freeze player
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:freezeplayer', function(player)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    if RSGCore.Functions.HasPermission(src, permissions['freeze']) or IsPlayerAceAllowed(src, 'command') then
        local target = GetPlayerPed(player.id)
        if not frozen then
            frozen = true
            FreezeEntityPosition(target, true)
            TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_111'), description = locale('sv_112')..player.name, type = 'inform' })
        else
            frozen = false
            FreezeEntityPosition(target, false)
            TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_113'), description = locale('sv_114')..player.name, type = 'inform' })
        end
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red', firstname..' '..lastname..' ' .. locale('sv_h') .. ' ' .. citizenid .. ' ' .. locale('sv_ban_e'), true)
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
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

    if RSGCore.Functions.HasPermission(src, permissions['spectate']) or IsPlayerAceAllowed(src, 'command') then
        local targetped = GetPlayerPed(player.id)
        local coords = GetEntityCoords(targetped)
        TriggerClientEvent('rsg-adminmenu:client:spectateplayer', src, player.id, coords)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red', firstname..' '..lastname..' ' .. locale('sv_h') .. ' '..citizenid..' ' .. locale('sv_ban_f'), true)
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
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

    if RSGCore.Functions.HasPermission(src, permissions['wildattack']) or IsPlayerAceAllowed(src, 'command') then
        TriggerClientEvent('rsg-adminmenu:client:wildattack', src, player.id)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red', firstname..' '..lastname..' ' .. locale('sv_h') .. ' '..citizenid..' ' .. locale('sv_ban_g'), true)
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
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

    if RSGCore.Functions.HasPermission(src, permissions['setonfire']) or IsPlayerAceAllowed(src, 'command') then
        TriggerClientEvent('rsg-adminmenu:client:playerfire', src, player.id)
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red', firstname..' '..lastname..' ' .. locale('sv_h') .. ' '..citizenid..' ' .. locale('sv_ban_h'), true)
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
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

    if RSGCore.Functions.HasPermission(src, permissions['giveitem']) or IsPlayerAceAllowed(src, 'command') then
        local id = player
        local Player_a = RSGCore.Functions.GetPlayer(id)
        local amount_a = amount
        Player_a.Functions.AddItem(item, amount_a)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_135'), description = locale('sv_136'), type = 'inform' })
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red', firstname..' '..lastname..' ' .. locale('sv_h') .. ' '..citizenid..' ' .. locale('sv_ban_i'), true)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
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

    if RSGCore.Functions.HasPermission(src, permissions['playerinfo']) or IsPlayerAceAllowed(src, 'command') then
        local id = player.id
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

        cb({
            firstname  = targetfirstname,
            lastname   = targetlastname,
            job        = targetjob,
            grade      = targetgrade,
            cash       = targetcash,
            bloodmoney = targetbloodmoney,
            bank       = targetbank,
            valbank    = targetvalbank,
            rhobank    = targetrhobank,
            blkbank    = targetblkbank,
            armbank    = targetarmbank,
            citizenid  = targetcitizenid,
            serverid   = targetserverid,
        })
    else
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red', firstname..' '..lastname..' ' .. locale('sv_h') .. ' '..citizenid..' ' .. locale('sv_ban_j'), true)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- Command to open the report menu
-----------------------------------------------------------------------
RSGCore.Commands.Add('report', locale('sv_report_command_desc'), {}, false, function(source)
    local src = source
    TriggerClientEvent('rsg-adminmenu:client:openreportmenu', src)
end)