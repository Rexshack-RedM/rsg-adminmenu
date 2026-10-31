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
-- wild attack troll action
-------------------------------------------------------------------
local attackAnimals = {
    joaat("a_c_wolf_small"),
    joaat("a_c_bearblack_01"),
    joaat("a_c_dogrufus_01")
}

local animalGroupHash = joaat("Animal")
local playerGroupHash = joaat("PLAYER")

local function TargetPed(serverId)
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    return ped ~= 0 and ped or nil
end

RegisterNetEvent('rsg-adminmenu:client:wildattack', function(serverId)
    local playerPed = TargetPed(serverId)
    if not playerPed then return end
    local animalHash = attackAnimals[math.random(#attackAnimals)]
    if not pcall(RSGCore.Functions.RequestModel, animalHash, 5000) then return end

    local spawn = GetOffsetFromEntityInWorldCoords(playerPed, 100.0, -15.0, 0.0)
    local _, groundZ = GetGroundZAndNormalFor_3dCoord(spawn.x, spawn.y, spawn.z + 50.0)
    local animalPed = CreatePed(animalHash, spawn.x, spawn.y, groundZ or spawn.z, GetEntityHeading(playerPed), true, false)
    SetModelAsNoLongerNeeded(animalHash)
    if animalPed == 0 then return end

    EquipMetaPedOutfitPreset(animalPed, 1, false)
    SetPedFleeAttributes(animalPed, 0, false)
    SetPedRelationshipGroupHash(animalPed, animalGroupHash)
    SetRelationshipBetweenGroups(5, animalGroupHash, playerGroupHash)
    SetRelationshipBetweenGroups(5, playerGroupHash, animalGroupHash)
    TaskPutPedDirectlyIntoMelee(animalPed, playerPed, 0.0, -1.0, 0.0, false)
    SetPedAsNoLongerNeeded(animalPed)
end)

RegisterNetEvent('rsg-adminmenu:client:playerfire', function(serverId)
    local playerPed = TargetPed(serverId)
    if playerPed then StartEntityFire(playerPed) end
end)
