local RSGCore = exports['rsg-core']:GetCoreObject()

local function Notify(title, description, notifyType)
    RSGCore.Functions.Notify({ title = title, description = description, type = notifyType or 'inform' })
end

-------------------------------
-- open the admin dashboard (server only fires this after a permission check)
-------------------------------
RegisterNetEvent('rsg-adminmenu:client:openadminmenu', function(data)
    local playerData = RSGCore.Functions.GetPlayerData()
    if not playerData or not playerData.citizenid then return end
    data = data or {}
    local flags = data.roleFlags or {}

    NUI.Open({
        mode = 'admin',
        self = {
            name = data.discordName or (playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname),
            citizenid = playerData.citizenid,
            job = { label = playerData.job and playerData.job.label or nil },
            avatarUrl = data.discordAvatar,
        },
        permissions = {
            isAdmin = true,
            enablePlayerBlips = Config.EnablePlayerBlips == true,
            canManageHistory = flags.canManageHistory == true,
            canManageAdmins = flags.canManageAdmins == true,
            atLeastMod = flags.atLeastMod == true,
            atLeastAdmin = flags.atLeastAdmin == true,
            fullAccess = flags.fullAccess == true,
        },
    })
end)

-- sent when this player's staff role is removed while the panel is open
RegisterNetEvent('rsg-adminmenu:client:forceclose', function()
    NUI.Close()
end)

-------------------------------
-- players list / player info
-------------------------------
RegisterNuiCallback('getPlayers', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getplayers', function(players)
        local mapped = {}
        for _, v in ipairs(players or {}) do
            mapped[#mapped + 1] = { id = v.id, name = v.name, citizenid = v.citizenid }
        end
        cb(mapped)
    end)
end)

RegisterNuiCallback('getPlayerInfo', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getplayerinfo', function(result)
        cb(result or {})
    end, { id = data.id })
end)

-------------------------------
-- player actions (all validated again on the server)
-------------------------------
RegisterNuiCallback('revivePlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:playerrevive', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('openInventory', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:openinventory', { id = data.id })
    NUI.Close() -- the inventory needs focus
    cb({ success = true })
end)

RegisterNuiCallback('kickPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:kickplayer', data.id, data.reason)
    cb({ success = true })
end)

RegisterNuiCallback('banPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:banplayer', data.id, data.duration, data.reason)
    cb({ success = true })
end)

RegisterNuiCallback('goToPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:gotoplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('bringPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:bringplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('toggleFreeze', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:freezeplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('toggleSpectate', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:spectateplayer', { id = data.id })
    NUI.Close() -- nothing to watch with the panel covering the screen
    cb({ success = true })
end)

RegisterNuiCallback('giveItem', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:giveitem', data.id, data.item, data.quantity)
    cb({ success = true })
end)

-------------------------------
-- dashboard / players page / statistics
-------------------------------
RegisterNuiCallback('getDashboardStats', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getdashboardstats', function(stats)
        cb(stats or {})
    end)
end)

RegisterNuiCallback('getBotLogo', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getbotlogo', function(result)
        cb(result or {})
    end)
end)

RegisterNuiCallback('getAllPlayersManaged', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getallplayersmanaged', function(result)
        cb(result or {})
    end)
end)

RegisterNuiCallback('unbanPlayer', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:unbanplayer', function(result)
        cb(result or { success = false })
    end, { banId = data.banId })
end)

RegisterNuiCallback('getStatistics', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getstatistics', function(result)
        cb(result or {})
    end)
end)

-------------------------------------------------------------------
-- self tools: the server authorises + logs each toggle, then it's applied here
-------------------------------------------------------------------
local godmode = false
local invisible = false
local playerBlipsEnabled = false
local playerBlips = {}

local function ClearPlayerBlips()
    for _, blip in pairs(playerBlips) do RemoveBlip(blip) end
    playerBlips = {}
end

local function SetGodmode(enabled)
    godmode = enabled
    SetPlayerInvincible(PlayerId(), enabled)
    if enabled then
        -- re-applied slowly so a respawn (new ped) mid-godmode stays covered
        CreateThread(function()
            while godmode do
                SetPlayerInvincible(PlayerId(), true)
                Wait(2000)
            end
        end)
    end
end

local function SetInvisible(enabled)
    invisible = enabled
    SetEntityVisible(PlayerPedId(), not enabled)
end

local function UpdatePlayerBlips(players)
    local seen = {}
    local myId = GetPlayerServerId(PlayerId())
    for _, player in ipairs(players or {}) do
        if player.id ~= myId then
            seen[player.id] = true
            local blip = playerBlips[player.id]
            if not blip then
                blip = BlipAddForCoords(1664425300, player.coords.x, player.coords.y, player.coords.z)
                SetBlipSprite(blip, joaat('blip_ambient_companion'), true)
                SetBlipScale(blip, 0.6)
                SetBlipName(blip, 'ID: ' .. player.id .. ' ' .. (player.name or ''))
                playerBlips[player.id] = blip
            else
                SetBlipCoords(blip, player.coords.x, player.coords.y, player.coords.z)
            end
        end
    end
    for id, blip in pairs(playerBlips) do
        if not seen[id] then
            RemoveBlip(blip)
            playerBlips[id] = nil
        end
    end
end

local function SetPlayerBlips(enabled)
    playerBlipsEnabled = enabled
    if not enabled then return ClearPlayerBlips() end
    CreateThread(function()
        while playerBlipsEnabled do
            local players = RSGCore.Functions.AwaitCallback('rsg-adminmenu:server:getplayers')
            if not playerBlipsEnabled then break end
            UpdatePlayerBlips(players)
            Wait(2000)
        end
        ClearPlayerBlips()
    end)
end

local selfToggles = {
    godmode = { get = function() return godmode end, set = SetGodmode, on = { 'cl_client_46', 'cl_client_47' }, off = { 'cl_client_48', 'cl_client_49' } },
    invisible = { get = function() return invisible end, set = SetInvisible, on = { 'cl_client_44', 'cl_client_45' }, off = { 'cl_client_42', 'cl_client_43' } },
    playerblips = { get = function() return playerBlipsEnabled end, set = SetPlayerBlips, on = { 'cl_client_156', 'cl_client_157' }, off = { 'cl_client_158', 'cl_client_159' } },
    -- DoorIds lives in client_doorid.lua, which loads after this file
    doorids = { get = function() return DoorIds.IsEnabled() end, set = function(v) DoorIds.SetEnabled(v) end, on = { 'cl_door_on' }, off = { 'cl_door_off' } },
}

RegisterNuiCallback('getSelfToolState', function(_, cb)
    cb({ godmode = godmode, invisible = invisible, playerblips = playerBlipsEnabled, doorids = DoorIds.IsEnabled() })
end)

RegisterNuiCallback('selfTool', function(data, cb)
    local tool = data and data.tool

    if tool == 'revive' then
        local result = RSGCore.Functions.AwaitCallback('rsg-adminmenu:server:selfrevive')
        return cb({ success = result and result.success == true })
    end

    if tool == 'marker' then
        local result = RSGCore.Functions.AwaitCallback('rsg-adminmenu:server:selftool', nil, { tool = 'marker' })
        if result and result.success then TriggerEvent('RSGCore:Command:GoToMarker') end
        return cb({ success = result and result.success == true })
    end

    local toggle = selfToggles[tool]
    if not toggle then return cb({ success = false }) end

    local enabled = not toggle.get()
    local result = RSGCore.Functions.AwaitCallback('rsg-adminmenu:server:selftool', nil, { tool = tool, enabled = enabled })
    if not result or not result.success then return cb({ success = false, enabled = toggle.get() }) end

    toggle.set(enabled)
    local text = enabled and toggle.on or toggle.off
    Notify(locale(text[1]), text[2] and locale(text[2]) or nil)
    cb({ success = true, enabled = enabled })
end)

--------------------
-- spectate player
--------------------
local isSpectating = false
local lastSpectateCoord = nil

local function SetSpectatorBody(spectating)
    local ped = PlayerPedId()
    SetEntityVisible(ped, not spectating and not invisible)
    SetEntityCollision(ped, not spectating, not spectating)
    SetEntityInvincible(ped, spectating)
    FreezeEntityPosition(ped, spectating)
    NetworkSetEntityInvisibleToNetwork(ped, spectating)
end

local function StopSpectating()
    if not isSpectating then return end
    isSpectating = false
    NetworkSetInSpectatorMode(false, PlayerPedId())
    if lastSpectateCoord then
        SetEntityCoords(PlayerPedId(), lastSpectateCoord.x, lastSpectateCoord.y, lastSpectateCoord.z, false, false, false, false)
    end
    SetSpectatorBody(false)
    lastSpectateCoord = nil
end

RegisterNetEvent('rsg-adminmenu:client:spectateplayer', function(targetServerId, targetCoords)
    if isSpectating then return StopSpectating() end

    local ped = PlayerPedId()
    lastSpectateCoord = GetEntityCoords(ped)
    isSpectating = true
    SetSpectatorBody(true)

    -- a far-away target isn't streamed in yet: move (hidden) below them until it is
    local targetPlayer = GetPlayerFromServerId(targetServerId)
    if targetPlayer == -1 and targetCoords then
        SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z - 15.0, false, false, false, false)
        local timeout = GetGameTimer() + 5000
        while GetPlayerFromServerId(targetServerId) == -1 and GetGameTimer() < timeout do Wait(100) end
        targetPlayer = GetPlayerFromServerId(targetServerId)
    end

    local targetPed = targetPlayer ~= -1 and GetPlayerPed(targetPlayer) or 0
    if targetPed == 0 then
        StopSpectating()
        return Notify(locale('cl_spectate'), locale('cl_report_player_offline'), 'error')
    end

    NetworkSetInSpectatorMode(true, targetPed)
    Notify(locale('cl_spectate'), locale('cl_spectate_stop_hint'))

    -- stop automatically when the target leaves
    CreateThread(function()
        while isSpectating do
            Wait(1000)
            if not NetworkIsPlayerActive(GetPlayerFromServerId(targetServerId)) then StopSpectating() end
        end
    end)
end)

-- Page Up opens the panel, or ends spectating when active
RegisterRawKeymap('adminmenu', nil, function()
    if isSpectating then return StopSpectating() end
    local playerData = RSGCore.Functions.GetPlayerData()
    if playerData and playerData.citizenid and not NUI.IsOpen() then
        ExecuteCommand('adminmenu')
    end
end, 0x21, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    StopSpectating()
    ClearPlayerBlips()
    if godmode then SetPlayerInvincible(PlayerId(), false) end
    if invisible then SetEntityVisible(PlayerPedId(), true) end
end)
