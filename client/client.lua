local RSGCore = exports['rsg-core']:GetCoreObject()

-- self-tool state (shared by the NUI callbacks and the event handlers below)
local invisible = false
local godmode = false
local playerBlipsEnabled = false
local playerBlips = {}

local function Notify(title, description, notifyType)
    RSGCore.Functions.Notify({ title = title, description = description, type = notifyType or 'inform', duration = 5000 })
end

-- logs a self-tool toggle through rsg-log
local function LogSelfAction(localeKey)
    TriggerServerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('cl_adminmenu'), 'red',
        GetPlayerName(PlayerId()) .. ' (ID: ' .. GetPlayerServerId(PlayerId()) .. ') ' .. locale(localeKey))
end

-- Page Up opens the panel (the server decides whether you're allowed in)
RegisterRawKeymap('adminmenu', nil, function()
    if LocalPlayer.state.isLoggedIn then ExecuteCommand('adminmenu') end
end, 0x21, false)

-------------------------------
-- open the admin dashboard (server only fires this after a permission check)
-------------------------------
RegisterNetEvent('rsg-adminmenu:client:openadminmenu', function(data)
    local playerData = RSGCore.Functions.GetPlayerData()
    if not playerData or not playerData.citizenid then return end
    local flags = (data and data.roleFlags) or {}

    NUI.Open({
        mode = 'admin',
        self = {
            name = (data and data.discordName) or (playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname),
            citizenid = playerData.citizenid,
            job = { label = playerData.job and playerData.job.label or nil },
            avatarUrl = data and data.discordAvatar or nil,
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
-- player actions (every one is re-checked on the server)
-------------------------------
local function Relay(nuiName, serverEvent)
    RegisterNuiCallback(nuiName, function(data, cb)
        TriggerServerEvent(serverEvent, { id = data.id })
        cb({ success = true })
    end)
end

Relay('revivePlayer', 'rsg-adminmenu:server:playerrevive')
Relay('openInventory', 'rsg-adminmenu:server:openinventory')
Relay('goToPlayer', 'rsg-adminmenu:server:gotoplayer')
Relay('bringPlayer', 'rsg-adminmenu:server:bringplayer')
Relay('toggleFreeze', 'rsg-adminmenu:server:freezeplayer')
Relay('toggleSpectate', 'rsg-adminmenu:server:spectateplayer')

RegisterNuiCallback('kickPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:kickplayer', { id = data.id }, data.reason)
    cb({ success = true })
end)

RegisterNuiCallback('banPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:banplayer', { id = data.id }, data.duration, data.reason)
    cb({ success = true })
end)

RegisterNuiCallback('giveItem', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:giveitem', { id = data.id }, data.item, data.quantity)
    cb({ success = true })
end)

-------------------------------
-- dashboard / players pages
-------------------------------
local function Fetch(nuiName, callbackName, fallback)
    RegisterNuiCallback(nuiName, function(data, cb)
        RSGCore.Functions.TriggerCallback(callbackName, function(result)
            cb(result or fallback)
        end, data)
    end)
end

Fetch('getDashboardStats', 'rsg-adminmenu:server:getdashboardstats', {})
Fetch('getBotLogo', 'rsg-adminmenu:server:getbotlogo', {})
Fetch('getAllPlayersManaged', 'rsg-adminmenu:server:getallplayersmanaged', {})
Fetch('getStatistics', 'rsg-adminmenu:server:getstatistics', {})
Fetch('unbanPlayer', 'rsg-adminmenu:server:unbanplayer', { success = false })

-------------------------------------------------------------------
-- self tools: teleport to marker / self revive / IDs / invisible / godmode / blips
-------------------------------------------------------------------
RegisterNuiCallback('teleportToMarker', function(_, cb)
    TriggerEvent('RSGCore:Command:GoToMarker')
    cb({ success = true })
end)

RegisterNuiCallback('selfRevive', function(_, cb)
    TriggerServerEvent('rsg-adminmenu:server:selfrevive')
    cb({ success = true })
end)

RegisterNuiCallback('toggleIds', function(_, cb)
    ExecuteCommand('txAdmin:menu:togglePlayerIDs')
    cb({ success = true })
end)

RegisterNuiCallback('toggleInvisible', function(_, cb)
    TriggerEvent('rsg-adminmenu:client:goinvisible')
    cb({ enabled = invisible })
end)

RegisterNuiCallback('toggleGodmode', function(_, cb)
    TriggerEvent('rsg-adminmenu:client:godmode')
    cb({ enabled = godmode })
end)

RegisterNuiCallback('togglePlayerBlips', function(_, cb)
    TriggerEvent('rsg-adminmenu:client:toggleplayerblips')
    cb({ enabled = playerBlipsEnabled })
end)

-------------------------------------------------------------------
-- player blips (server only returns positions to staff)
-------------------------------------------------------------------
local function ClearPlayerBlips()
    for _, blip in pairs(playerBlips) do RemoveBlip(blip) end
    playerBlips = {}
end

local function UpdatePlayerBlips(players)
    local myServerId = GetPlayerServerId(PlayerId())
    local seen = {}
    for _, player in ipairs(players or {}) do
        if player.id ~= myServerId and player.coords then
            seen[player.id] = true
            local blip = playerBlips[player.id]
            if not blip then
                blip = BlipAddForCoords(1664425300, player.coords.x, player.coords.y, player.coords.z)
                SetBlipSprite(blip, joaat('blip_ambient_companion'), true)
                SetBlipScale(blip, 0.6)
                SetBlipName(blip, ('ID: %s %s'):format(player.id, player.name or ''))
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

AddEventHandler('rsg-adminmenu:client:toggleplayerblips', function()
    if not Config.EnablePlayerBlips then return end
    playerBlipsEnabled = not playerBlipsEnabled

    if not playerBlipsEnabled then
        ClearPlayerBlips()
        Notify(locale('cl_client_158'), locale('cl_client_159'))
        LogSelfAction('cl_adminmenu_f')
        return
    end

    Notify(locale('cl_client_156'), locale('cl_client_157'))
    LogSelfAction('cl_adminmenu_e')
    CreateThread(function()
        while playerBlipsEnabled do
            local players = RSGCore.Functions.AwaitCallback('rsg-adminmenu:server:getplayers', 5000)
            if playerBlipsEnabled then UpdatePlayerBlips(players) end
            Wait(2000)
        end
        ClearPlayerBlips()
    end)
end)

-------------------------------------------------------------------
-- invisible
-------------------------------------------------------------------
AddEventHandler('rsg-adminmenu:client:goinvisible', function()
    invisible = not invisible
    SetEntityVisible(PlayerPedId(), not invisible)
    if invisible then
        Notify(locale('cl_client_44'), locale('cl_client_45'))
        LogSelfAction('cl_adminmenu_a')
    else
        Notify(locale('cl_client_42'), locale('cl_client_43'))
        LogSelfAction('cl_adminmenu_d')
    end
end)

-------------------------------------------------------------------
-- god mode (SetPlayerInvincible takes the player index, not the ped)
-------------------------------------------------------------------
AddEventHandler('rsg-adminmenu:client:godmode', function()
    godmode = not godmode
    if godmode then
        Notify(locale('cl_client_46'), locale('cl_client_47'))
        LogSelfAction('cl_adminmenu_b')
        CreateThread(function()
            -- re-applied every few seconds so it survives respawns / ped swaps
            while godmode do
                SetPlayerInvincible(PlayerId(), true)
                SetEntityInvincible(PlayerPedId(), true)
                Wait(2000)
            end
            SetPlayerInvincible(PlayerId(), false)
            SetEntityInvincible(PlayerPedId(), false)
        end)
    else
        Notify(locale('cl_client_48'), locale('cl_client_49'))
        LogSelfAction('cl_adminmenu_c')
    end
end)

-------------------------------------------------------------------
-- spectate
-------------------------------------------------------------------
local lastSpectateCoord = nil
local isSpectating = false

local function StopSpectating()
    if not isSpectating then return end
    isSpectating = false
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    NetworkSetEntityInvisibleToNetwork(ped, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    if lastSpectateCoord then
        SetEntityCoords(ped, lastSpectateCoord.x, lastSpectateCoord.y, lastSpectateCoord.z, false, false, false, false)
    end
    SetEntityVisible(ped, not invisible)
    SetEntityInvincible(ped, godmode)
    lastSpectateCoord = nil
end

RegisterNetEvent('rsg-adminmenu:client:spectateplayer', function(targetServerId, targetCoords)
    if isSpectating then return StopSpectating() end

    local ped = PlayerPedId()
    lastSpectateCoord = GetEntityCoords(ped)
    isSpectating = true
    SetEntityVisible(ped, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    NetworkSetEntityInvisibleToNetwork(ped, true)

    -- the target may be out of scope: move under them first so their ped streams in
    local targetPlayer = GetPlayerFromServerId(targetServerId)
    if targetPlayer == -1 and targetCoords then
        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z - 50.0, false, false, false, false)
        local timeout = GetGameTimer() + 5000
        repeat
            Wait(100)
            targetPlayer = GetPlayerFromServerId(targetServerId)
        until targetPlayer ~= -1 or GetGameTimer() > timeout
    end

    local targetPed = targetPlayer ~= -1 and GetPlayerPed(targetPlayer) or 0
    if targetPed == 0 then
        StopSpectating()
        Notify(locale('cl_adminmenu'), locale('sv_invalid_input'), 'error')
        return
    end
    NetworkSetInSpectatorMode(true, targetPed)
end)

-------------------------------------------------------------------
-- cleanup
-------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    playerBlipsEnabled = false
    ClearPlayerBlips()
    StopSpectating()
    if godmode then
        SetPlayerInvincible(PlayerId(), false)
        SetEntityInvincible(PlayerPedId(), false)
    end
    if invisible then SetEntityVisible(PlayerPedId(), true) end
end)

-- current self-tool toggles, so the Self Tools page shows the right state
RegisterNuiCallback('getSelfToolState', function(_, cb)
    cb({ godmode = godmode, invisible = invisible, playerBlips = playerBlipsEnabled })
end)
