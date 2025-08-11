local RSGCore = exports['rsg-core']:GetCoreObject()

-- Avertir un joueur (utilise le même système de permissions que rsg-adminmenu)
RegisterNetEvent('rsg-adminmenu:server:warnplayer', function(targetId, reason)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid
    
    -- Vérification des permissions (même système que rsg-adminmenu)
    if RSGCore.Functions.HasPermission(src, 'admin') or IsPlayerAceAllowed(src, 'command') then
        local targetPlayer = RSGCore.Functions.GetPlayer(targetId)
        if not targetPlayer then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_player_not_found'),
                type = 'error'
            })
            return
        end
        
        -- Envoyer l'avertissement au joueur
        TriggerClientEvent('rsg-adminmenu:client:receivewarning', targetId, reason)
        
        -- Log de l'action (même système que rsg-adminmenu)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', 
            locale('sv_warning_log_title'), 'orange', 
            string.format(locale('sv_warning_log_desc'),
                firstname, lastname, 
                targetPlayer.PlayerData.charinfo.firstname,
                targetPlayer.PlayerData.charinfo.lastname,
                reason
            )
        )
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_warning_sent'),
            description = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname,
            type = 'success'
        })
    else
        -- Même système de bannissement que rsg-adminmenu
        BanPlayer(src)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_g'), 'red', 
            firstname..' '..lastname..' ' .. locale('sv_h') .. ' '..citizenid..' a tenté d\'utiliser warn player', true)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_101'), description = locale('sv_102'), type = 'inform' })
    end
end)
