local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

RegisterNuiCallback('wildAttack', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:wildattack', { id = data.id })
    cb({ success = true })
end)

RegisterNuiCallback('setOnFire', function(data, cb)
    TriggerServerEvent('rsg-adminmenu:server:playerfire', { id = data.id })
    cb({ success = true })
end)

-------------------------------------------------------------------
-- wild attack troll action
-------------------------------------------------------------------
local attackAnimals = {
    joaat("a_c_wolf_small"),
    joaat("a_c_bearblack_01"),
    joaat("a_c_dogrufus_01")
}

local animalGroupHash = joaat("Animal")
local playerGroupHash = joaat("PLAYER")

RegisterNetEvent('rsg-adminmenu:client:wildattack', function(player)
    local targetplayer = GetPlayerFromServerId(player)
    local playerPed = GetPlayerPed(targetplayer)
    local animalHash = attackAnimals[math.random(#attackAnimals)]
    local coordsBehindPlayer = GetOffsetFromEntityInWorldCoords(playerPed, 100, -15.0, 0)
    local playerHeading = GetEntityHeading(playerPed)
    local belowGround, groundZ, vec3OnFloor = GetGroundZAndNormalFor_3dCoord(coordsBehindPlayer.x, coordsBehindPlayer.y, coordsBehindPlayer.z)

    -- request model
    RequestModel(animalHash)
    while not HasModelLoaded(animalHash) do
        Wait(15)
    end

    -- creating animal
    animalPed = CreatePed(animalHash, coordsBehindPlayer.x, coordsBehindPlayer.y, groundZ, playerHeading, true, false)
    EquipMetaPedOutfitPreset(animalPed, 1, 0)

    -- setting player as enemy
    SetPedFleeAttributes(animalPed, 0, 0)
    SetPedRelationshipGroupHash(animalPed, animalGroupHash)
    TaskSetBlockingOfNonTemporaryEvents(animalPed, true)
    TaskCombatHatedTargetsAroundPed(animalPed, 30.0, 0)
    ClearPedTasks(animalPed)
    TaskPutPedDirectlyIntoMelee(animalPed, playerPed, 0.0, -1.0, 0.0, 0)
    SetRelationshipBetweenGroups(5, animalGroupHash, playerGroupHash)
    SetRelationshipBetweenGroups(5, playerGroupHash, animalGroupHash)
    SetModelAsNoLongerNeeded(animalHash)

end)

-------------------------------------------------------------------
-- set player on fire troll action
-------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:playerfire', function(player)
    local targetplayer = GetPlayerFromServerId(player)
    local playerPed = GetPlayerPed(targetplayer)
    StartEntityFire(playerPed)
end)
