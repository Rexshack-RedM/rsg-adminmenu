local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterNuiCallback('wildAttack', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:wildattack', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('setOnFire', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:playerfire', { id = data.id })
    cb({ success = true })
end)

-------------------------------------------------------------------
-- both effects run on the target's own client, so they work at any
-- distance from the admin who triggered them
-- (wolf / bear / dog models as used by the original version of this action)
-------------------------------------------------------------------
local attackAnimals = { joaat('a_c_wolf_small'), joaat('a_c_bearblack_01'), joaat('a_c_dogrufus_01') }
local ANIMAL_DESPAWN_MS = 60000

RegisterNetEvent('rsg-adminmenu:client:wildattack', function()
    local playerPed = PlayerPedId()
    local animalHash = attackAnimals[math.random(#attackAnimals)]
    local spawn = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, -15.0, 0.0)
    local _, groundZ = GetGroundZAndNormalFor_3dCoord(spawn.x, spawn.y, spawn.z + 10.0)

    if not pcall(RSGCore.Functions.RequestModel, animalHash, 5000) then return end

    local animalPed = CreatePed(animalHash, spawn.x, spawn.y, groundZ ~= 0 and groundZ or spawn.z, GetEntityHeading(playerPed), true, false, false, false)
    SetModelAsNoLongerNeeded(animalHash)
    if not DoesEntityExist(animalPed) then return end

    SetRandomOutfitVariation(animalPed, true)
    SetPedFleeAttributes(animalPed, 0, false)
    SetBlockingOfNonTemporaryEvents(animalPed, true)
    TaskCombatPed(animalPed, playerPed, 0, 16)

    -- don't leave the animal in the world forever
    SetTimeout(ANIMAL_DESPAWN_MS, function()
        if DoesEntityExist(animalPed) then
            SetEntityAsNoLongerNeeded(animalPed)
        end
    end)
end)

RegisterNetEvent('rsg-adminmenu:client:playerfire', function()
    StartEntityFire(PlayerPedId(), 1.0, 0, 0)
end)
