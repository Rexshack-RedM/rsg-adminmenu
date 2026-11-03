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

local SNOW_COVERAGE_XMAS, SNOW_COVERAGE_PRIMARY = 2, 0 -- eSnowCoverageType (natives db: _SET_SNOW_COVERAGE_TYPE)

local function ApplyWeather(w)
    if not w then return end
    -- SET_WEATHER_TYPE
    Citizen.InvokeNative(0x59174F1AFE095B5A, joaat(w.type or 'SUNNY'), true, true, true, (tonumber(w.transition) or 0) + 0.0, false)
    -- _SET_SNOW_COVERAGE_TYPE ("permanent snow mode" in the panel)
    Citizen.InvokeNative(0xF02A9C330BBFC5C7, w.snow and SNOW_COVERAGE_XMAS or SNOW_COVERAGE_PRIMARY)
end

local function ApplyWind(w)
    if not w then return end

    SetWindSpeed(((tonumber(w.speed) or 0) / 100) * 12.0)
    SetWindDirection(math.rad(tonumber(w.direction) or 0))
end

-- the server only sends sections an admin has actually set
local latestSettings = nil

RegisterNetEvent('rsg-adminmenu:client:applyworldsettings', function(settings)
    if type(settings) ~= 'table' then return end
    latestSettings = settings
    ApplyTime(settings.time)
    ApplyWeather(settings.weather)
    if settings.timescale then SetTimeScale((tonumber(settings.timescale) or 1) + 0.0) end
    ApplyWind(settings.wind)
end)

-- frozen sections are re-applied so other weather/time scripts can't drift them
CreateThread(function()
    while true do
        Wait(5000)
        local s = latestSettings
        if s then
            if s.time and s.time.freeze then ApplyTime(s.time) end
            if s.weather and s.weather.freeze then ApplyWeather(s.weather) end
            if s.wind and s.wind.freeze then ApplyWind(s.wind) end
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

