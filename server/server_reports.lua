local RSGCore = exports['rsg-core']:GetCoreObject()

-- Créer un report joueur
RegisterNetEvent('rsg-adminmenu:server:createplayerreport', function(targetId, reason)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local targetPlayer = RSGCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_reports_player_not_found'),
            type = 'error'
        })
        return
    end
    
    -- Sauvegarder en base de données
    MySQL.insert('INSERT INTO reports (reporter_id, reporter_name, reported_id, reported_name, reason, type, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        src,
        Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        targetId,
        targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname,
        reason,
        'player',
        'open',
        os.date('%Y-%m-%d %H:%M:%S')
    })
    
    -- Webhook Discord avec textes localisés
    local embed = {
        {
            color = 16711680, -- Rouge
            title = locale('sv_webhook_player_report_title'),
            description = string.format(locale('sv_webhook_player_report_desc'),
                Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                src,
                targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname,
                targetId,
                reason
            ),
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }
    
    if Config.Reports.PlayerReportWebhook and Config.Reports.PlayerReportWebhook ~= '' then
        PerformHttpRequest(Config.Reports.PlayerReportWebhook, function() end, 'POST', 
            json.encode({embeds = embed, content = Config.Reports.PlayerReportRoles}), 
            {['Content-Type'] = 'application/json'}
        )
    end
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_reports_player_sent'),
        type = 'success'
    })
end)

-- Créer un report bug
RegisterNetEvent('rsg-adminmenu:server:createbugreport', function(bugDesc, doing, location)
    local src = source  
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Sauvegarder en base de données
    MySQL.insert('INSERT INTO reports (reporter_id, reporter_name, reason, type, status, created_at) VALUES (?, ?, ?, ?, ?, ?)', {
        src,
        Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        string.format(locale('sv_bug_report_format'), bugDesc, doing or locale('sv_not_specified'), location or locale('sv_not_specified')),
        'bug',
        'open',
        os.date('%Y-%m-%d %H:%M:%S')
    })
    
    -- Webhook Discord avec textes localisés
    local embed = {
        {
            color = 16776960, -- Jaune
            title = locale('sv_webhook_bug_report_title'),
            description = string.format(locale('sv_webhook_bug_report_desc'),
                Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                src,
                bugDesc,
                doing or locale('sv_not_specified'),
                location or locale('sv_not_specified')
            ),
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }
    
    if Config.Reports.BugReportWebhook and Config.Reports.BugReportWebhook ~= '' then
        PerformHttpRequest(Config.Reports.BugReportWebhook, function() end, 'POST',
            json.encode({embeds = embed, content = Config.Reports.BugReportRoles}),
            {['Content-Type'] = 'application/json'}
        )
    end
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_reports_bug_sent'),
        type = 'success'
    })
end)

-- Récupérer la liste des reports
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getreports', function(source, cb)
    local src = source
    
    if not RSGCore.Functions.HasPermission(src, 'admin') then
        cb(false)
        return
    end
    
    MySQL.query('SELECT * FROM reports WHERE status = ? ORDER BY created_at DESC', {'open'}, function(result)
        cb(result)
    end)
end)

-- Clore un report
RegisterNetEvent('rsg-adminmenu:server:closereport', function(reportId, reason)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not RSGCore.Functions.HasPermission(src, 'admin') then return end
    
    MySQL.update('UPDATE reports SET status = ?, closed_by = ?, closed_reason = ?, closed_at = ? WHERE id = ?', {
        'closed',
        Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        reason,
        os.date('%Y-%m-%d %H:%M:%S'),
        reportId
    })
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_reports_closed'),
        type = 'success'
    })
end)
