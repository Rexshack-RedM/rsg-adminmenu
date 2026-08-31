local RSGCore = exports['rsg-core']:GetCoreObject()

-----------------------------------------------------------------------
-- admins page
-----------------------------------------------------------------------
RegisterNuiCallback('getAdmins', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getadmins', function(result)
        cb(result or {})
    end)
end)

RegisterNuiCallback('getRoleConfig', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getroleconfig', function(result)
        cb(result or {})
    end)
end)

RegisterNuiCallback('addAdmin', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:addadmin', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNuiCallback('changeAdminRole', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:changeadminrole', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNuiCallback('removeAdmin', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:removeadmin', function(result)
        cb(result or { success = false })
    end, data)
end)

-----------------------------------------------------------------------
-- logs page
-----------------------------------------------------------------------
RegisterNuiCallback('getLogs', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getlogs', function(result)
        cb(result or { logs = {}, total = 0, page = 1, perPage = 20, counts = {} })
    end, data)
end)

RegisterNuiCallback('sendLogToDiscord', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:sendlogtodiscord', function(result)
        cb(result or { success = false })
    end, data)
end)

-----------------------------------------------------------------------
-- admin chat page
-----------------------------------------------------------------------
RegisterNuiCallback('getAdminChatMessages', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getadminchatmessages', function(result)
        cb(result or {})
    end)
end)

RegisterNuiCallback('createAdminChatMessage', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:createadminchatmessage', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNetEvent('rsg-adminmenu:client:adminchatmessage', function(payload)
    NUI.SendMessage('adminChatMessage', payload)
end)
