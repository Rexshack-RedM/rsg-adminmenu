local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

RegisterNuiCallback('getFinanceData', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getPlayerData', function(result)
        cb(result or {})
    end, data.id)
end)

RegisterNuiCallback('giveMoney', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:financeadd', data.id, data.type, data.amount)
    cb({ success = true })
end)

RegisterNuiCallback('removeMoney', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:financeremove', data.id, data.type, data.amount)
    cb({ success = true })
end)
