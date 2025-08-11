local RSGCore = exports['rsg-core']:GetCoreObject()

lib.locale()

-- Menu d'avertissement (utilise les mêmes fonctions que rsg-adminmenu)
RegisterNetEvent('rsg-adminmenu:client:warnplayer', function(data)
    local input = lib.inputDialog(locale('cl_warn_title') .. ': ' .. data.name, {
        {type = 'input', label = locale('cl_warn_reason'), required = true},
        {type = 'checkbox', label = locale('cl_warn_confirm'), required = true}
    })
    
    if not input then return end
    if not input[2] then 
        lib.notify({title = locale('cl_warn_not_confirmed'), type = 'error'})
        return 
    end
    
    TriggerServerEvent('rsg-adminmenu:server:warnplayer', data.id, input[1])
end)

-- Recevoir un avertissement (compatible RedM avec gel de véhicule)
RegisterNetEvent('rsg-adminmenu:client:receivewarning', function(reason)
    local playerPed = cache.ped
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    -- Gel du véhicule si le joueur est dedans
    if vehicle ~= 0 then
        FreezeEntityPosition(vehicle, true)
    end
    
    FreezeEntityPosition(playerPed, true)
    
    local alert = lib.alertDialog({
        header = locale('cl_warn_received_title'),
        content = locale('cl_warn_received_desc') .. reason,
        centered = true,
        cancel = false
    })
    
    if alert == 'confirm' then
        if vehicle ~= 0 then
            FreezeEntityPosition(vehicle, false)
        end
        FreezeEntityPosition(playerPed, false)
    end
end)
