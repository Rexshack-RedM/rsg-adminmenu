local RSGCore = exports['rsg-core']:GetCoreObject()

-----------------------------------------------------------------------
-- server actions
-----------------------------------------------------------------------
RegisterNuiCallback('getServerState', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getserverstate', function(result)
        cb(result or { closed = false })
    end)
end)

RegisterNuiCallback('toggleCloseServer', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:togglecloseserver', function(result)
        cb(result or { success = false })
    end)
end)

RegisterNuiCallback('kickAllPlayers', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:kickallplayers', function(result)
        cb(result or { success = false })
    end)
end)

RegisterNuiCallback('refreshResources', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:refreshresources', function(result)
        cb(result or { success = false })
    end)
end)

RegisterNuiCallback('sendAnnouncement', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:sendannouncement', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNuiCallback('getWorldSettings', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getworldsettings', function(result)
        cb(result or {})
    end)
end)

RegisterNuiCallback('setTimeSettings', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:settimesettings', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNuiCallback('setWeatherSettings', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:setweathersettings', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNuiCallback('setTimescale', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:settimescale', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNuiCallback('setWindSettings', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:setwindsettings', function(result)
        cb(result or { success = false })
    end, data)
end)

local weekdays = { 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday' }

local function ApplyTime(t)
    if not t then return end
    if t.day then
        local targetIndex = nil
        for i, d in ipairs(weekdays) do
            if d == t.day then targetIndex = i - 1 end
        end
        if targetIndex then
            local diff = (targetIndex - GetClockDayOfWeek()) % 7
            if diff ~= 0 then
                SetClockDate(GetClockDayOfMonth() + diff, GetClockMonth(), GetClockYear())
            end
        end
    end
    SetClockTime(tonumber(t.hour) or 0, tonumber(t.minute) or 0, tonumber(t.second) or 0)
    PauseClock(t.freeze and true or false)
end

local function ApplyWeather(w)
    if not w then return end

    Citizen.InvokeNative(0x59174F1AFE095B5A, GetHashKey(w.type or 'SUNNY'), true, true, true,
        (tonumber(w.transition) or 0) + 0.0, false)
end

local function ApplyWind(w)
    if not w then return end

    SetWindSpeed(((tonumber(w.speed) or 0) / 100) * 12.0)
    SetWindDirection(math.rad(tonumber(w.direction) or 0))
end

local latestSettings = nil

local function ApplyAll(settings)
    latestSettings = settings
    ApplyTime(settings.time)
    ApplyWeather(settings.weather)
    SetTimeScale((tonumber(settings.timescale) or 1) + 0.0)
    ApplyWind(settings.wind)
end

RegisterNetEvent('rsg-adminmenu:client:applyworldsettings', function(settings)
    ApplyAll(settings)
end)


CreateThread(function()
    while true do
        Wait(5000)
        if latestSettings then
            if latestSettings.time and latestSettings.time.freeze then ApplyTime(latestSettings.time) end
            if latestSettings.weather and latestSettings.weather.freeze then ApplyWeather(latestSettings.weather) end
            if latestSettings.wind and latestSettings.wind.freeze then ApplyWind(latestSettings.wind) end
        end
    end
end)


RegisterNuiCallback('getResources', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getresources', function(result)
        cb(result or {})
    end)
end)


RegisterNuiCallback('getWebhookSettings', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getwebhooksettings', function(result)
        cb(result or {})
    end)
end)

RegisterNuiCallback('saveWebhookSettings', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:savewebhooksettings', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNuiCallback('getCustomItems', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getcustomitems', function(result)
        cb(result or {})
    end)
end)

RegisterNuiCallback('addCustomItem', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:addcustomitem', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNuiCallback('deleteCustomItem', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:deletecustomitem', function(result)
        cb(result or { success = false })
    end, data)
end)
