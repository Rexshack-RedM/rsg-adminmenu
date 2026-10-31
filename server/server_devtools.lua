local RSGCore = exports['rsg-core']:GetCoreObject()

local function CanUseServerSettings(src)
    return HasAdminPermission(src, 'serversettings')
end

local serverClosed = false

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    if not serverClosed then return end
    if IsPlayerAceAllowed(src, 'god') then return end
    deferrals.defer()
    Wait(0)
    deferrals.done(locale('sv_server_closed'))
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getserverstate', function(source, cb)
    if not HasAdminPermission(source, 'adminmenu') then return cb({ closed = false }) end
    cb({ closed = serverClosed })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:togglecloseserver', function(source, cb)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    serverClosed = not serverClosed
    LogAdminAction('server_event', 'high', src,
        serverClosed and locale('sv_log_closed_server') or locale('sv_log_reopened_server'), nil, nil)
    cb({ success = true, closed = serverClosed })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:kickallplayers', function(source, cb)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    local count = 0
    for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
        if tostring(playerId) ~= tostring(src) then
            DropPlayer(playerId, locale('sv_kick_all_reason'))
            count = count + 1
        end
    end
    LogAdminAction('server_event', 'high', src, locale('sv_log_kicked_all_players'), locale('sv_log_players_removed', count), nil)
    cb({ success = true, count = count })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:refreshresources', function(source, cb)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end

    CreateThread(function()
        ExecuteCommand('refresh')
        LogAdminAction('server_event', 'low', src, locale('sv_log_refreshed_server_resources'), nil, nil)
        cb({ success = true })
    end)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:sendannouncement', function(source, cb, data)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    local message = type(data) == 'table' and CleanText(data.message, 500)
    if not message then
        cb({ success = false })
        return
    end
    TriggerClientEvent('chat:addMessage', -1, {
        template = "<div class='chat-message server'><strong>[" .. locale('sv_announcement') .. "] {0}:</strong> {1}</div>",
        args = { AdminDisplayName(src), message },
    })
    LogAdminAction('server_event', 'medium', src, locale('sv_log_sent_server_announcement'), message, nil)
    cb({ success = true })
end)

local worldSettings = {
    time = { day = nil, hour = 6, minute = 0, second = 0, transition = 5, freeze = false },
    weather = { type = 'SUNNY', transition = 5, freeze = false, snow = false },
    timescale = 1,
    wind = { direction = 0, speed = 0, freeze = false },
}

-- nothing is pushed to players until an admin changes a setting, so by default
-- rsg-weather stays in charge of time and weather. Only the sections an admin
-- has touched are sent.
local touched = {}

local function BroadcastWorldSettings(target)
    if not next(touched) then return end
    local payload = {}
    for key in pairs(touched) do payload[key] = worldSettings[key] end
    TriggerClientEvent('rsg-adminmenu:client:applyworldsettings', target or -1, payload)
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    BroadcastWorldSettings(Player.PlayerData.source)
end)

local function clampNum(v, min, max, default)
    v = tonumber(v)
    if not v or v ~= v then return default end
    return math.max(min, math.min(max, v))
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getworldsettings', function(source, cb)
    if not CanUseServerSettings(source) then return cb({}) end
    cb(worldSettings)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:settimesettings', function(source, cb, data)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    if type(data) ~= 'table' then return cb({ success = false }) end
    worldSettings.time = {
        day = type(data.day) == 'string' and data.day or nil,
        hour = math.floor(clampNum(data.hour, 0, 23, 0)),
        minute = math.floor(clampNum(data.minute, 0, 59, 0)),
        second = math.floor(clampNum(data.second, 0, 59, 0)),
        transition = clampNum(data.transition, 0, 600, 0),
        freeze = data.freeze and true or false,
    }
    touched.time = true
    BroadcastWorldSettings()
    LogAdminAction('server_event', 'low', src, locale('sv_log_updated_server_time_settings'), nil, nil)
    cb({ success = true })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:setweathersettings', function(source, cb, data)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    if type(data) ~= 'table' then return cb({ success = false }) end
    touched.weather = true
    worldSettings.weather = {
        type = type(data.type) == 'string' and data.type:upper():gsub('[^%w_]', '') or 'SUNNY',
        transition = clampNum(data.transition, 0, 600, 0),
        freeze = data.freeze and true or false,
        snow = data.snow and true or false,
    }
    BroadcastWorldSettings()
    LogAdminAction('server_event', 'low', src, locale('sv_log_updated_server_weather_settings'), tostring(data.type), nil)
    cb({ success = true })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:settimescale', function(source, cb, data)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    if type(data) ~= 'table' then return cb({ success = false }) end
    touched.timescale = true
    worldSettings.timescale = clampNum(data.timescale, 0.0, 10.0, 1)
    BroadcastWorldSettings()
    LogAdminAction('server_event', 'low', src, locale('sv_log_updated_server_timescale'), tostring(worldSettings.timescale), nil)
    cb({ success = true })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:setwindsettings', function(source, cb, data)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    if type(data) ~= 'table' then return cb({ success = false }) end
    touched.wind = true
    worldSettings.wind = {
        direction = clampNum(data.direction, 0, 360, 0),
        speed = clampNum(data.speed, 0, 100, 0),
        freeze = data.freeze and true or false,
    }
    BroadcastWorldSettings()
    LogAdminAction('server_event', 'low', src, locale('sv_log_updated_server_wind_settings'), nil, nil)
    cb({ success = true })
end)

-----------------------------------------------------------------------
-- resource management
-----------------------------------------------------------------------
-- Refresh Resources on the Server Settings page still needs command.refresh.
-- needs this line in server.cfg:  add_ace resource.rsg-adminmenu command.refresh allow
CreateThread(function()
    if not IsPrincipalAceAllowed('resource.' .. GetCurrentResourceName(), 'command.refresh') then
        print(('^3[%s] Refresh Resources needs: add_ace resource.%s command.refresh allow^7'):format(GetCurrentResourceName(), GetCurrentResourceName()))
    end
end)

local function collectMetadata(name, key)
    local out = {}
    local i = 0
    while i < 64 do
        local v = GetResourceMetadata(name, key, i)
        if v == nil then break end
        if v ~= '' then out[#out + 1] = v end
        i = i + 1
    end
    return out
end

-- LoadResourceFile cannot read fxmanifest.lua (it isn't in files {}), so
-- that path always returned nothing. Read the file off disk instead.
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

local function dependenciesFromManifest(name)
    local manifest = readManifestFile(name)
    if not manifest then return {} end
    local deps, seen = {}, {}
    local function add(dep)
        if type(dep) ~= 'string' then return end
        dep = dep:match('^%s*(.-)%s*$') or dep
        if dep == '' or dep:sub(1, 1) == '/' or seen[dep] then return end
        seen[dep] = true
        deps[#deps + 1] = dep
    end
    for dep in manifest:gmatch("[Dd]ependency%s+['\"]([^'\"]+)['\"]") do
        add(dep)
    end
    for block in manifest:gmatch("[Dd]ependencies%s*{([^}]+)}") do
        for dep in block:gmatch("['\"]([^'\"]+)['\"]") do
            add(dep)
        end
    end
    return deps
end

local function getResourceDependencies(name)
    local seen, deps = {}, {}
    local function addAll(list)
        for _, dep in ipairs(list) do
            if type(dep) == 'string' and dep ~= '' and dep:sub(1, 1) ~= '/' and not seen[dep] then
                seen[dep] = true
                deps[#deps + 1] = dep
            end
        end
    end
    addAll(collectMetadata(name, 'dependency'))
    addAll(collectMetadata(name, 'dependencies'))
    addAll(dependenciesFromManifest(name))
    return deps
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getresources', function(source, cb)
    local src = source
    if not CanUseServerSettings(src) then
        cb({})
        return
    end
    local list = {}
    local count = GetNumResources()
    for i = 0, count - 1 do
        local name = GetResourceByFindIndex(i)
        if name then
            list[#list + 1] = {
                name = name,
                state = GetResourceState(name),
                version = GetResourceMetadata(name, 'version', 0),
                author = GetResourceMetadata(name, 'author', 0),
                description = GetResourceMetadata(name, 'description', 0),
                -- joined string so NUI JSON never turns an empty Lua table into
                -- `{}` (which has no .length and always rendered as "No dependencies")
                dependencies = table.concat(getResourceDependencies(name), ', '),
            }
        end
    end
    cb(list)
end)
