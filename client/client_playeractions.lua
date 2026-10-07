local RSGCore = exports['rsg-core']:GetCoreObject()

-------------------------------------------------------------------
-- admin-side NUI callbacks — forward into the server events added in
-- server.lua, same 1:1 pattern as every other RegisterNuiCallback in client.lua
-------------------------------------------------------------------
RegisterNuiCallback('healPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:healplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('killPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:killplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('ragdollPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:ragdollplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('lightningPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:lightningplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('toHeavenPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:toheavenplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('drainStaminaPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:drainstaminaplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('drunkPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:drunkplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('handcuffPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:handcuffplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('setPermission', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:setpermission', { id = data.id }, data.level)
    cb({ success = true })
end)

RegisterNuiCallback('warnPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:warnplayer', { id = data.id }, data.reason, data.severity)
    cb({ success = true })
end)

RegisterNuiCallback('setJob', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:setjob', { id = data.id }, data.job, data.grade)
    cb({ success = true })
end)

RegisterNuiCallback('setCharField', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:setcharfield', { id = data.id }, data.field, data.value)
    cb({ success = true })
end)

RegisterNuiCallback('adjustXp', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:adjustxp', { id = data.id }, data.direction, data.amount)
    cb({ success = true })
end)

RegisterNuiCallback('clearWeapons', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:clearweapons', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('clearItems', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:clearitems', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('getAllItems', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getallitems', function(items)
        cb(items or {})
    end)
end)

RegisterNuiCallback('removePlayerItem', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:removeplayeritem', function(result)
        cb(result or { success = false })
    end, { id = data.id, item = data.item, amount = data.amount, slot = data.slot })
end)

RegisterNuiCallback('getPlayerHistory', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getplayerhistory', function(history)
        cb(history or {})
    end, { citizenid = data.citizenid })
end)

RegisterNuiCallback('deleteHistoryEntry', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:deletehistoryentry', function(result)
        cb(result or { success = false })
    end, { id = data.id })
end)

RegisterNuiCallback('jumpScarePlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:jumpscareplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('horseBuckPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:horsebuckplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('hauntedPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:hauntedplayer', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('everyoneAttackPlayer', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:everyoneattackplayer', { id = data.id })
    cb({ success = true })
end)

-------------------------------------------------------------------
-- target-side effect handlers — these run on the affected player's own
-- client since ragdoll/stamina/camera natives only apply locally
-------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:killplayer', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

RegisterNetEvent('rsg-adminmenu:client:ragdollplayer', function()
    SetPedToRagdoll(PlayerPedId(), 3000, 3000, 0, false, false, false)
end)

RegisterNetEvent('rsg-adminmenu:client:lightningplayer', function()
    local ped = PlayerPedId()
    ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 1.5)
    SetEntityHealth(ped, math.max(1, GetEntityHealth(ped) - 50))
end)

RegisterNetEvent('rsg-adminmenu:client:drainstaminaplayer', function()
    SetPlayerStamina(PlayerId(), 0.0)
end)

RegisterNetEvent('rsg-adminmenu:client:drunkplayer', function()
    SetTimecycleModifier('drunk')
    CreateThread(function()
        local endTime = GetGameTimer() + 15000
        while GetGameTimer() < endTime do
            ShakeGameplayCam('DRUNK_SHAKE', 0.3)
            Wait(500)
        end
        ClearTimecycleModifier()
    end)
end)

RegisterNetEvent('rsg-adminmenu:client:clearweapons', function()
    RemoveAllPedWeapons(PlayerPedId(), true)
end)

RegisterNetEvent('rsg-adminmenu:client:jumpscareplayer', function()
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 1.2)

    -- fullscreen image + sound, handled entirely in the NUI overlay (see
    -- App.tsx's JumpscareOverlay) since it's always mounted regardless of
    -- whether this player has the admin panel open. (Deliberately no spawned
    -- animal ped here anymore — its own ambient vocalization was competing
    -- with the custom jumpscare.mp3.)
    NUI.SendMessage('jumpscare', {})
end)

RegisterNetEvent('rsg-adminmenu:client:horsebuckplayer', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local mount = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, mount, 4160) -- 4160 = bail out / forced abrupt exit
        Wait(300)
    end
    SetEntityVelocity(ped, 0.0, 0.0, 3.5)
    SetPedToRagdoll(ped, 1500, 1500, 0, false, false, false)
end)

RegisterNetEvent('rsg-adminmenu:client:hauntedplayer', function()
    CreateThread(function()
        local ped = PlayerPedId()
        local endTime = GetGameTimer() + 8000
        while GetGameTimer() < endTime do
            ShakeGameplayCam('DRUNK_SHAKE', 0.5)
            PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            SetEntityAlpha(ped, 150, false)
            Wait(150)
            ResetEntityAlpha(ped)
            Wait(1500)
        end
    end)
end)

RegisterNetEvent('rsg-adminmenu:client:everyoneattackplayer', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local handle, entity = FindFirstPed()
    local success
    repeat
        if DoesEntityExist(entity) and entity ~= ped and not IsPedAPlayer(entity) and not IsEntityDead(entity) then
            if #(GetEntityCoords(entity) - coords) < 40.0 then
                ClearPedTasks(entity)
                TaskCombatPed(entity, ped, 0, 16)
            end
        end
        success, entity = FindNextPed(handle)
    until not success
    EndFindPed(handle)
end)
