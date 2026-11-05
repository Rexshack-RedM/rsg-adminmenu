local RSGCore = exports['rsg-core']:GetCoreObject()

local WEEKDAYS = { Sunday = true, Monday = true, Tuesday = true, Wednesday = true, Thursday = true, Friday = true, Saturday = true }

local function CanUseServerSettings(src)
    return HasAdminPermission(src, 'serversettings')
end

local function Clamp(value, min, max, default)
    value = tonumber(value)
    if not value or value ~= value then return default end
    return math.max(min, math.min(max, value))
end

local serverClosed = false

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    if not serverClosed or IsPlayerAceAllowed(src, 'god') then return end
    deferrals.defer()
    Wait(0)
    deferrals.done(locale('sv_server_closed'))
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getserverstate', function(source, cb)
    if not CanUseServerSettings(source) then return cb({ closed = false }) end
    cb({ closed = serverClosed })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:togglecloseserver', function(source, cb)
    local src = source
    if not CanUseServerSettings(src) then return cb({ success = false }) end
    serverClosed = not serverClosed
    LogAdminAction('server_event', 'high', src, serverClosed and locale('sv_log_closed_server') or locale('sv_log_reopened_server'), nil, nil)
    cb({ success = true, closed = serverClosed })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:kickallplayers', function(source, cb)
    local src = source
    if not CanUseServerSettings(src) then return cb({ success = false }) end
    local count = 0
    for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
        if playerId ~= src then
            DropPlayer(playerId, locale('sv_kick_all_reason'))
            count = count + 1
        end
    end
    LogAdminAction('server_event', 'high', src, locale('sv_log_kicked_all_players'), locale('sv_log_players_removed', count), nil)
    cb({ success = true, count = count })
end)

-- needs `add_ace resource.rsg-adminmenu command.refresh allow` in server.cfg
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:refreshresources', function(source, cb)
    local src = source
    if not CanUseServerSettings(src) then return cb({ success = false }) end
    if not IsPrincipalAceAllowed('resource.' .. GetCurrentResourceName(), 'command.refresh') then
        return cb({ success = false, message = locale('sv_refresh_ace_missing', GetCurrentResourceName()) })
    end
    ExecuteCommand('refresh')
    LogAdminAction('server_event', 'low', src, locale('sv_log_refreshed_server_resources'), nil, nil)
    cb({ success = true })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:sendannouncement', function(source, cb, data)
    local src = source
    local message = SanitizeText(type(data) == 'table' and data.message, 500)
    if not CanUseServerSettings(src) or not message then return cb({ success = false }) end
    TriggerClientEvent('chat:addMessage', -1, {
        template = "<div class='chat-message server'><strong>[" .. locale('sv_announcement') .. "] {0}:</strong> {1}</div>",
        args = { AdminDisplayName(src), message },
    })
    LogAdminAction('server_event', 'medium', src, locale('sv_log_sent_server_announcement'), message, nil)
    cb({ success = true })
end)

-----------------------------------------------------------------------
-- world settings: a section stays nil until an admin sets it, so this
-- resource never overrides rsg-weather's time/weather on its own
-----------------------------------------------------------------------
local defaults = {
    time = { day = nil, hour = 6, minute = 0, second = 0, transition = 5, freeze = false },
    weather = { type = 'SUNNY', transition = 5, freeze = false, snow = false },
    timescale = 1,
    wind = { direction = 0, speed = 0, freeze = false },
}
local worldSettings = {}

local function BroadcastWorldSettings(target)
    if next(worldSettings) then
        TriggerClientEvent('rsg-adminmenu:client:applyworldsettings', target or -1, worldSettings)
    end
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    BroadcastWorldSettings(Player.PlayerData.source)
end)

-- when rsg-weather is running it owns time/weather/wind: send the change through its
-- exports so it syncs to everyone (with regional translation) instead of fighting it
local DAY_INDEX = { Sunday = 0, Monday = 1, Tuesday = 2, Wednesday = 3, Thursday = 4, Friday = 5, Saturday = 6 }
local function WeatherResourceRunning() return GetResourceState('rsg-weather') == 'started' end

local function RouteToRsgWeather(key, v)
    if not WeatherResourceRunning() then return false end
    local rw = exports['rsg-weather']
    if key == 'weather' then
        return rw:setWeather(v.type:lower(), math.max(0.1, v.transition), v.freeze, v.snow) ~= false
    elseif key == 'time' then
        local day = DAY_INDEX[v.day] or rw:getTime().day
        rw:setTime(day, v.hour, v.minute, v.second, math.floor(v.transition * 1000), v.freeze)
        return true
    elseif key == 'wind' then
        rw:setWind(v.direction, (v.speed / 100) * 12.0, v.freeze)
        return true
    end
    return false -- timescale (game speed) stays with the admin menu
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getworldsettings', function(source, cb)
    if not CanUseServerSettings(source) then return cb(defaults) end
    if WeatherResourceRunning() then
        local rw = exports['rsg-weather']
        local st, t, w = rw:getState(), rw:getTime(), rw:getWind()
        local names = { 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday' }
        return cb({
            time = { day = names[(t.day % 7) + 1], hour = t.hour, minute = t.minute, second = t.second, transition = 5, freeze = st.timeFrozen },
            weather = { type = st.weather:upper(), transition = 5, freeze = st.weatherFrozen, snow = st.permanentSnow },
            timescale = worldSettings.timescale or defaults.timescale,
            wind = { direction = w.direction, speed = math.floor(w.speed / 12.0 * 100), freeze = st.windFrozen },
        })
    end
    cb({
        time = worldSettings.time or defaults.time,
        weather = worldSettings.weather or defaults.weather,
        timescale = worldSettings.timescale or defaults.timescale,
        wind = worldSettings.wind or defaults.wind,
    })
end)

local function RegisterWorldSetting(callback, logKey, build)
    RSGCore.Functions.CreateCallback('rsg-adminmenu:server:' .. callback, function(source, cb, data)
        local src = source
        if not CanUseServerSettings(src) or type(data) ~= 'table' then return cb({ success = false }) end
        local key, value, details = build(data)
        if not key then return cb({ success = false }) end
        if not RouteToRsgWeather(key, value) then
            worldSettings[key] = value
            BroadcastWorldSettings()
        end
        LogAdminAction('server_event', 'low', src, locale(logKey), details, nil)
        cb({ success = true })
    end)
end

RegisterWorldSetting('settimesettings', 'sv_log_updated_server_time_settings', function(data)
    return 'time', {
        day = WEEKDAYS[data.day] and data.day or nil,
        hour = math.floor(Clamp(data.hour, 0, 23, 0)),
        minute = math.floor(Clamp(data.minute, 0, 59, 0)),
        second = math.floor(Clamp(data.second, 0, 59, 0)),
        transition = Clamp(data.transition, 0, 300, 0),
        freeze = data.freeze == true,
    }
end)

RegisterWorldSetting('setweathersettings', 'sv_log_updated_server_weather_settings', function(data)
    local weatherType = type(data.type) == 'string' and data.type:upper() or ''
    if not weatherType:match('^[A-Z]+$') or #weatherType > 32 then return nil end
    return 'weather', {
        type = weatherType,
        transition = Clamp(data.transition, 0, 300, 0),
        freeze = data.freeze == true,
        snow = data.snow == true,
    }, weatherType
end)

RegisterWorldSetting('settimescale', 'sv_log_updated_server_timescale', function(data)
    local scale = Clamp(data.timescale, 0, 100, 1)
    return 'timescale', scale, tostring(scale)
end)

RegisterWorldSetting('setwindsettings', 'sv_log_updated_server_wind_settings', function(data)
    return 'wind', {
        direction = Clamp(data.direction, 0, 360, 0),
        speed = Clamp(data.speed, 0, 100, 0),
        freeze = data.freeze == true,
    }
end)

-----------------------------------------------------------------------
-- resource management
-----------------------------------------------------------------------
local function collectMetadata(name, key)
    local out = {}
    for i = 0, 63 do
        local v = GetResourceMetadata(name, key, i)
        if v == nil then break end
        if v ~= '' then out[#out + 1] = v end
    end
    return out
end

-- LoadResourceFile cannot read fxmanifest.lua (it isn't in files {}), so read it off disk
local function readManifestFile(name)
    local base = GetResourcePath(name)
    if io and io.open and base and base ~= '' then
        base = base:gsub('\\', '/'):gsub('/+$', '')
        local f = io.open(base .. '/fxmanifest.lua', 'r') or io.open(base .. '/__resource.lua', 'r')
        if f then
            local body = f:read('*a')
            f:close()
            if body and body ~= '' then return body end
        end
    end
    return LoadResourceFile(name, 'fxmanifest.lua') or LoadResourceFile(name, '__resource.lua')
end

local function getResourceDependencies(name)
    local seen, deps = {}, {}
    local function add(dep)
        if type(dep) ~= 'string' then return end
        dep = dep:match('^%s*(.-)%s*$') or dep
        if dep == '' or dep:sub(1, 1) == '/' or seen[dep] then return end
        seen[dep] = true
        deps[#deps + 1] = dep
    end

    for _, dep in ipairs(collectMetadata(name, 'dependency')) do add(dep) end
    for _, dep in ipairs(collectMetadata(name, 'dependencies')) do add(dep) end

    local manifest = readManifestFile(name)
    if manifest then
        for dep in manifest:gmatch("[Dd]ependency%s+['\"]([^'\"]+)['\"]") do add(dep) end
        for block in manifest:gmatch("[Dd]ependencies%s*{([^}]+)}") do
            for dep in block:gmatch("['\"]([^'\"]+)['\"]") do add(dep) end
        end
    end
    return deps
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getresources', function(source, cb)
    if not CanUseServerSettings(source) then return cb({}) end
    local list = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name then
            list[#list + 1] = {
                name = name,
                state = GetResourceState(name),
                version = GetResourceMetadata(name, 'version', 0),
                author = GetResourceMetadata(name, 'author', 0),
                description = GetResourceMetadata(name, 'description', 0),
                -- joined string so NUI JSON never turns an empty Lua table into `{}`
                dependencies = table.concat(getResourceDependencies(name), ', '),
            }
        end
    end
    cb(list)
end)
