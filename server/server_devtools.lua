local RSGCore = exports['rsg-core']:GetCoreObject()

local function CanUseServerSettings(src)
    return RSGCore.Functions.HasPermission(src, permissions['serversettings']) or IsPlayerAceAllowed(src, 'god')
end

-----------------------------------------------------------------------
-- server actions
-----------------------------------------------------------------------
local serverClosed = false

-- rejects new connections while the server is marked closed, admins excepted
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    if not serverClosed then return end
    if IsPlayerAceAllowed(src, 'god') then return end
    deferrals.defer()
    Wait(0)
    deferrals.done('The server is currently closed to new connections.')
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getserverstate', function(source, cb)
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
        serverClosed and 'Closed server for new players' or 'Reopened server for new players', nil, nil)
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
            DropPlayer(playerId, 'Removed by an administrator (server-wide kick)')
            count = count + 1
        end
    end
    LogAdminAction('server_event', 'high', src, 'Kicked all players', count .. ' player(s) removed', nil)
    cb({ success = true, count = count })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:refreshresources', function(source, cb)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    ExecuteCommand('refresh')
    LogAdminAction('server_event', 'low', src, 'Refreshed server resources', nil, nil)
    cb({ success = true })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:sendannouncement', function(source, cb, data)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    local message = data and data.message
    if not message or message == '' then
        cb({ success = false })
        return
    end
    TriggerClientEvent('chat:addMessage', -1, {
        template = "<div class='chat-message server'><strong>[ANNOUNCEMENT] " .. AdminDisplayName(src) .. ":</strong> {0}</div>",
        args = { message },
    })
    LogAdminAction('server_event', 'medium', src, 'Sent server announcement', message, nil)
    cb({ success = true })
end)

-----------------------------------------------------------------------
-- world settings (time / weather / wind / timescale) — this resource holds
-- the authoritative values and pushes them to every client (including on
-- join), which then applies them locally via natives on its own
-----------------------------------------------------------------------
local worldSettings = {
    time = { day = nil, hour = 6, minute = 0, second = 0, transition = 5, freeze = false },
    weather = { type = 'SUNNY', transition = 5, freeze = false, snow = false },
    timescale = 1,
    wind = { direction = 0, speed = 0, freeze = false },
}

local function BroadcastWorldSettings(target)
    TriggerClientEvent('rsg-adminmenu:client:applyworldsettings', target or -1, worldSettings)
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    BroadcastWorldSettings(Player.PlayerData.source)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getworldsettings', function(source, cb)
    cb(worldSettings)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:settimesettings', function(source, cb, data)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    worldSettings.time = {
        day = data.day,
        hour = tonumber(data.hour) or 0,
        minute = tonumber(data.minute) or 0,
        second = tonumber(data.second) or 0,
        transition = tonumber(data.transition) or 0,
        freeze = data.freeze and true or false,
    }
    BroadcastWorldSettings()
    LogAdminAction('server_event', 'low', src, 'Updated server time settings', nil, nil)
    cb({ success = true })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:setweathersettings', function(source, cb, data)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    worldSettings.weather = {
        type = data.type or 'SUNNY',
        transition = tonumber(data.transition) or 0,
        freeze = data.freeze and true or false,
        snow = data.snow and true or false,
    }
    BroadcastWorldSettings()
    LogAdminAction('server_event', 'low', src, 'Updated server weather settings', tostring(data.type), nil)
    cb({ success = true })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:settimescale', function(source, cb, data)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    worldSettings.timescale = tonumber(data.timescale) or 1
    BroadcastWorldSettings()
    LogAdminAction('server_event', 'low', src, 'Updated server timescale', tostring(worldSettings.timescale), nil)
    cb({ success = true })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:setwindsettings', function(source, cb, data)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    worldSettings.wind = {
        direction = tonumber(data.direction) or 0,
        speed = tonumber(data.speed) or 0,
        freeze = data.freeze and true or false,
    }
    BroadcastWorldSettings()
    LogAdminAction('server_event', 'low', src, 'Updated server wind settings', nil, nil)
    cb({ success = true })
end)

-----------------------------------------------------------------------
-- resource management
-----------------------------------------------------------------------
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
            local depCount = GetNumResourceMetadata(name, 'dependency') or 0
            local dependencies = {}
            for d = 0, depCount - 1 do
                dependencies[#dependencies + 1] = GetResourceMetadata(name, 'dependency', d)
            end
            list[#list + 1] = {
                name = name,
                state = GetResourceState(name),
                version = GetResourceMetadata(name, 'version', 0),
                author = GetResourceMetadata(name, 'author', 0),
                description = GetResourceMetadata(name, 'description', 0),
                dependencies = dependencies,
            }
        end
    end
    cb(list)
end)

-- states that count as a successful outcome for each command, once the
-- resource has had a moment to actually transition
local expectedStates = {
    start = { started = true, starting = true },
    restart = { started = true, starting = true },
    stop = { stopped = true, stopping = true, uninitialized = true },
}

local function ResourceAction(source, cb, command, name)
    local src = source
    if not CanUseServerSettings(src) then
        cb({ success = false })
        return
    end
    if not name or name == '' or GetResourceState(name) == 'missing' then
        cb({ success = false, reason = 'not_found' })
        return
    end

    local label = command:sub(1, 1):upper() .. command:sub(2)

    -- stopping/restarting THIS resource kills the very Lua context handling
    -- this very request partway through — the callback below would never run,
    -- and the NUI's request would just hang forever with no error shown
    -- (exactly what "the button doesn't work" looks like from the panel).
    -- Acknowledge first, then issue the command a moment later so the
    -- response has actually gone out before this resource goes down.
    if name == GetCurrentResourceName() then
        LogAdminAction('server_event', 'high', src, label .. ' resource', name, name)
        cb({ success = true })
        CreateThread(function()
            Wait(300)
            ExecuteCommand(command .. ' ' .. name)
        end)
        return
    end

    ExecuteCommand(command .. ' ' .. name)

    -- ExecuteCommand doesn't report whether the command actually took effect
    -- (a typo'd name, a resource that refuses to stop, etc. would previously
    -- have still reported success) — give it a moment, then check for real
    CreateThread(function()
        Wait(command == 'stop' and 500 or 1500)
        local newState = GetResourceState(name)
        local ok = expectedStates[command] and expectedStates[command][newState] or false
        if ok then
            LogAdminAction('server_event', 'medium', src, label .. ' resource', name, name)
        end
        cb({ success = ok, state = newState })
    end)
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:startresource', function(source, cb, data)
    ResourceAction(source, cb, 'start', data and data.name)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:stopresource', function(source, cb, data)
    ResourceAction(source, cb, 'stop', data and data.name)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:restartresource', function(source, cb, data)
    ResourceAction(source, cb, 'restart', data and data.name)
end)
