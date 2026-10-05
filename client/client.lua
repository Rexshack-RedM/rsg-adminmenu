local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- shared toggle state (declared up front so the NUI callbacks below and the
-- RegisterNetEvent handlers further down both close over the same locals)
local invisible = false
local godmode = false
local playerBlipsEnabled = false
local playerBlips = {}
local blipUpdateThread = nil

RegisterRawKeymap("adminmenu", nil, function()
    local playerData = RSGCore.Functions.GetPlayerData()
    if playerData and playerData.citizenid then
        ExecuteCommand('adminmenu')
    end
end, 0x21, false)

-- 0x21 = Page up key

-------------------------------
-- open the admin dashboard (server only fires this after a permission check)
-------------------------------
RegisterNetEvent('rsg-adminmenu:client:openadminmenu', function(data)
    local playerData = RSGCore.Functions.GetPlayerData()
    if not playerData or not playerData.citizenid then return end

    local displayName = (data and data.discordName) or (playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname)

    NUI.Open({
        mode = 'admin',
        self = {
            name = displayName,
            citizenid = playerData.citizenid,
            job = { label = playerData.job and playerData.job.label or nil },
            avatarUrl = data and data.discordAvatar or nil,
        },
        permissions = {
            isAdmin = true,
            enablePlayerBlips = Config.EnablePlayerBlips == true,
            canManageHistory = data and data.roleFlags and data.roleFlags.canManageHistory == true,
            canManageAdmins = data and data.roleFlags and data.roleFlags.canManageAdmins == true,
            atLeastMod = data and data.roleFlags and data.roleFlags.atLeastMod == true,
            atLeastAdmin = data and data.roleFlags and data.roleFlags.atLeastAdmin == true,
            fullAccess = data and data.roleFlags and data.roleFlags.fullAccess == true,
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
-- player actions
-------------------------------
RegisterNuiCallback('revivePlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:playerrevive', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('openInventory', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:openinventory', { id = data.id })
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
    local targetName = GetPlayerName(GetPlayerFromServerId(data.id)) or (locale('cl_client_id_prefix') .. ' ' .. data.id)
    TriggerServerEvent('rsg-adminmenu:server:freezeplayer', { id = data.id, name = targetName })
    cb({ success = true })
end)

RegisterNuiCallback('toggleSpectate', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:spectateplayer', { id = data.id })
    cb({ success = true })
end)

-------------------------------
-- give item (search happens client-side against RSGCore.Shared.Items, as before)
-------------------------------
RegisterNuiCallback('searchItems', function(data, cb)
    local items = RSGCore.Shared.Items
    local keyword = (data.query or ''):lower()
    local options = {}

    if keyword ~= '' then
        for _, item in pairs(items) do
            local label = item.label or item.name
            if label:lower():find(keyword, 1, true) then
                options[#options + 1] = { value = item.name, label = label }
                if #options >= 30 then break end
            end
        end
    end

    cb(options)
end)

RegisterNuiCallback('giveItem', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:giveitem', data.id, data.item, data.quantity)
    cb({ success = true })
end)

-------------------------------
-- dashboard stats
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

-------------------------------
-- server weather
-------------------------------
RegisterNuiCallback('openWeatherSync', function(_, cb)
    TriggerEvent('weathersync:openAdminUi')
    cb({ success = true })
end)

-------------------------------------------------------------------
-- admin options: teleport / self revive / toggle IDs
-------------------------------------------------------------------
RegisterNuiCallback('teleportToMarker', function(_, cb)
    TriggerEvent('RSGCore:Command:GoToMarker')
    cb({ success = true })
end)

RegisterNuiCallback('selfRevive', function(_, cb)
    TriggerEvent('rsg-medic:client:playerRevive')
    cb({ success = true })
end)

RegisterNuiCallback('toggleIds', function(_, cb)
    ExecuteCommand('txAdmin:menu:togglePlayerIDs')
    cb({ success = true })
end)

RegisterNuiCallback('toggleInvisible', function(_, cb)
    TriggerEvent('rsg-adminmenu:client:goinvisible')
    cb({ enabled = invisible == true })
end)

RegisterNuiCallback('toggleGodmode', function(_, cb)
    TriggerEvent('rsg-adminmenu:client:godmode')
    cb({ enabled = godmode == true })
end)

RegisterNuiCallback('togglePlayerBlips', function(_, cb)
    TriggerEvent('rsg-adminmenu:client:toggleplayerblips')
    cb({ enabled = playerBlipsEnabled == true })
end)

-------------------------------------------------------------------
-- toggle player blips
-------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:toggleplayerblips', function()
    local playerId = PlayerId()
    local serverId = GetPlayerServerId(playerId)
    local playerName = GetPlayerName(playerId)

    playerBlipsEnabled = not playerBlipsEnabled

    if playerBlipsEnabled then
        lib.notify({ title = locale('cl_client_156'), description = locale('cl_client_157'), type = 'inform' })
        TriggerServerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('cl_adminmenu'), 'red',
            playerName .. ' (ID: ' .. serverId .. ') ' .. locale('cl_adminmenu_e'))

        if not blipUpdateThread then
            blipUpdateThread = CreateThread(function()
                while playerBlipsEnabled do
                    Wait(1000)
                    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getplayers', function(players)
                        for _, player in pairs(players) do
                            if player.id ~= playerId then
                                if not playerBlips[player.id] then
                                    local blip = BlipAddForCoords(1664425300, player.coords.x, player.coords.y,
                                        player.coords.z)
                                    SetBlipSprite(blip, GetHashKey('blip_ambient_companion'))
                                    SetBlipScale(blip, 0.6)
                                    local steamName = GetPlayerName(GetPlayerFromServerId(player.id))
                                    SetBlipName(blip, 'ID: ' .. player.id .. ' ' .. steamName)
                                    playerBlips[player.id] = blip
                                else
                                    SetBlipCoords(playerBlips[player.id], player.coords.x, player.coords.y,
                                        player.coords.z)
                                end
                            end
                        end

                        for blipId, blip in pairs(playerBlips) do
                            local found = false
                            for _, player in pairs(players) do
                                if player.id == blipId then
                                    found = true
                                    break
                                end
                            end
                            if not found then
                                RemoveBlip(blip)
                                playerBlips[blipId] = nil
                            end
                        end
                    end)
                end
                blipUpdateThread = nil
            end)
        end
    else
        lib.notify({ title = locale('cl_client_158'), description = locale('cl_client_159'), type = 'inform' })
        TriggerServerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('cl_adminmenu'), 'red',
            playerName .. ' (ID: ' .. serverId .. ') ' .. locale('cl_adminmenu_f'))

        for _, blip in pairs(playerBlips) do
            RemoveBlip(blip)
        end
        playerBlips = {}
    end
end)

-------------------------------------------------------------------
-- go invisible
-------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:goinvisible', function()
    local playerId = PlayerId()
    local serverId = GetPlayerServerId(playerId)
    local playerName = GetPlayerName(playerId)

    if invisible then
        -- Invisibility disabled
        SetEntityVisible(cache.ped, true)
        invisible = false
        lib.notify({ title = locale('cl_client_42'), description = locale('cl_client_43'), type = 'inform' })
        TriggerServerEvent(
            'rsg-log:server:CreateLog',
            'adminmenu',
            locale('cl_adminmenu'),
            'red',
            playerName .. ' (ID: ' .. serverId .. ') ' .. locale('cl_adminmenu_d') -- disabled invisibility
        )
    else
        -- Invisibility enabled
        SetEntityVisible(cache.ped, false)
        invisible = true
        lib.notify({ title = locale('cl_client_44'), description = locale('cl_client_45'), type = 'inform' })
        TriggerServerEvent(
            'rsg-log:server:CreateLog',
            'adminmenu',
            locale('cl_adminmenu'),
            'red',
            playerName .. ' (ID: ' .. serverId .. ') ' .. locale('cl_adminmenu_a') -- enabled invisibility
        )
    end
end)

-------------------------------------------------------------------
-- god mode
-------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:godmode', function()
    godmode = not godmode

    local playerId = PlayerId()
    local serverId = GetPlayerServerId(playerId)
    local playerName = GetPlayerName(playerId)

    if godmode then
        -- Godmode enabled
        lib.notify({ title = locale('cl_client_46'), description = locale('cl_client_47'), type = 'inform' })
        TriggerServerEvent(
            'rsg-log:server:CreateLog',
            'adminmenu',
            locale('cl_adminmenu'),
            'red',
            playerName .. ' (ID: ' .. serverId .. ') ' .. locale('cl_adminmenu_b') -- enabled godmode
        )
        -- SetPlayerInvincible is a sticky flag, not a per-frame state — it stays
        -- set until explicitly changed, so this never needed a Wait(0) loop
        -- re-calling it hundreds of times a second. Still loop, just slowly, so
        -- a ped change mid-godmode (death/respawn) gets re-flagged invincible.
        CreateThread(function()
            while godmode do
                SetPlayerInvincible(cache.ped, true)
                Wait(2000)
            end
        end)
    else
        -- Godmode disabled
        SetPlayerInvincible(cache.ped, false)
        lib.notify({ title = locale('cl_client_48'), description = locale('cl_client_49'), type = 'inform' })
        TriggerServerEvent(
            'rsg-log:server:CreateLog',
            'adminmenu',
            locale('cl_adminmenu'),
            'red',
            playerName .. ' (ID: ' .. serverId .. ') ' .. locale('cl_adminmenu_c') -- disabled godmode
        )
    end
end)

------------------------
-- kick / ban announcements arrive through the server events unchanged
------------------------

--------------------
-- spectate player
--------------------

local lastSpectateCoord = nil
local isSpectating = false

RegisterNetEvent('rsg-adminmenu:client:spectateplayer', function(targetPed)
    local targetplayer = GetPlayerFromServerId(targetPed)
    local target = GetPlayerPed(targetplayer)
    if not isSpectating then
        isSpectating = true
        SetEntityVisible(cache.ped, false)                  -- Set invisible
        SetEntityCollision(cache.ped, false, false)         -- Set collision
        SetEntityInvincible(cache.ped, true)                -- Set invincible
        NetworkSetEntityInvisibleToNetwork(cache.ped, true) -- Set invisibility
        lastSpectateCoord = GetEntityCoords(cache.ped)      -- save my last coords
        NetworkSetInSpectatorMode(true, target)             -- Enter Spectate Mode
    else
        isSpectating = false
        NetworkSetInSpectatorMode(false, target)             -- Remove From Spectate Mode
        NetworkSetEntityInvisibleToNetwork(cache.ped, false) -- Set Visible
        SetEntityCollision(cache.ped, true, true)            -- Set collision
        SetEntityCoords(cache.ped, lastSpectateCoord)        -- Return Me To My Coords
        SetEntityVisible(cache.ped, true)                    -- Remove invisible
        SetEntityInvincible(cache.ped, false)                -- Remove godmode
        lastSpectateCoord = nil                              -- Reset Last Saved Coords
    end
end)
