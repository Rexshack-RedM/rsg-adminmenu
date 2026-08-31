local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local reportCooldown = false

-----------------------------------------------------------------------
-- open the report ticket UI (any player, no permission gate)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:openreportmenu', function()
    local playerData = RSGCore.Functions.GetPlayerData()
    if not playerData or not playerData.citizenid then return end

    NUI.Open({
        mode = 'player',
        self = {
            name = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname,
            citizenid = playerData.citizenid,
        },
    })
end)

-----------------------------------------------------------------------
-- create a report
-----------------------------------------------------------------------
RegisterNuiCallback('createReport', function(data, cb)
    if reportCooldown then
        cb({ success = false, message = locale('cl_report_cooldown_desc') })
        return
    end

    TriggerServerEvent('rsg-adminmenu:server:createreport', {
        reportType = data.reportType,
        title = data.title,
        description = data.description,
        reportedPlayerId = data.reportedPlayerId,
        imageUrl = data.imageUrl,
        severity = data.severity,
    })

    reportCooldown = true
    SetTimeout(Config.Reports.Cooldown * 1000, function()
        reportCooldown = false
    end)

    cb({ success = true })
end)

-----------------------------------------------------------------------
-- reports lists / details
-----------------------------------------------------------------------
RegisterNuiCallback('getMyReports', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getmyreports', function(reports)
        cb(reports or {})
    end)
end)

RegisterNuiCallback('getAllReports', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getallreports', function(reports)
        cb(reports or {})
    end)
end)

RegisterNuiCallback('getReportDetails', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getreportdetails', function(report, messages, nearbyPlayers)
        cb({ report = report, messages = messages or {}, nearbyPlayers = nearbyPlayers or {} })
    end, data.id)
end)

RegisterNuiCallback('replyReport', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:replyreport', data.id, data.message, 'player')
    cb({ success = true })
end)

-----------------------------------------------------------------------
-- admin report actions
-----------------------------------------------------------------------
RegisterNuiCallback('claimReport', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:claimreport', { reportId = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('releaseReport', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:releasereport', { reportId = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('resolveReport', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:resolvereport', { reportId = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('deleteReport', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:deletereport', data.id, data.reason)
    cb({ success = true })
end)

-----------------------------------------------------------------------
-- notifications (still fire as native HUD notifications regardless of NUI state)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:newreportnotification', function(reportData)
    local typeText = locale('cl_report_type_' .. reportData.report_type)
    lib.notify({
        title = locale('cl_report_new_notification'),
        description = locale('cl_report_new_desc', reportData.id, reportData.reporter_name, typeText),
        type = 'inform',
        duration = 10000,
        icon = 'fa-solid fa-bell'
    })
end)

RegisterNetEvent('rsg-adminmenu:client:reportreplynotification', function(reportData)
    lib.notify({
        title = locale('cl_report_reply_notification'),
        description = locale('cl_report_reply_notification_desc', reportData.reportId, reportData.adminName),
        type = 'inform',
        duration = 10000,
        icon = 'fa-solid fa-comment'
    })
end)
