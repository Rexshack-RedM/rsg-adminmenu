local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterNuiCallback('getCurrentCoords', function(_, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    cb({ x = coords.x, y = coords.y, z = coords.z, heading = heading })
end)

RegisterNuiCallback('teleportToCoords', function(data, cb)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, data.x + 0.0, data.y + 0.0, data.z + 0.0, false, false, false)
    if data.heading then
        SetEntityHeading(ped, data.heading + 0.0)
    end
    cb({ success = true })
end)

RegisterNuiCallback('getTeleportLocations', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getteleportlocations', function(result)
        cb(result or {})
    end)
end)

RegisterNuiCallback('addTeleportLocation', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:addteleportlocation', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNuiCallback('deleteTeleportLocation', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:deleteteleportlocation', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNuiCallback('getBlips', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getblips', function(result)
        cb(result or {})
    end)
end)

RegisterNuiCallback('addBlip', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:addblip', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNuiCallback('updateBlip', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:updateblip', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNuiCallback('deleteBlip', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:deleteblip', function(result)
        cb(result or { success = false })
    end, data)
end)

local activeBlipHandles = {}

RegisterNetEvent('rsg-adminmenu:client:syncblips', function(blips)

    for _, handle in ipairs(activeBlipHandles) do
        RemoveBlip(handle)
    end
    activeBlipHandles = {}

    for _, b in ipairs(blips or {}) do

        local blip = BlipAddForCoords(GetHashKey('BLIP_STYLE_POI'), b.x + 0.0, b.y + 0.0, b.z + 0.0)
  
        SetBlipSprite(blip, GetHashKey(b.sprite), true)
        SetBlipScale(blip, (tonumber(b.scale) or 1.0) + 0.0)
        SetBlipName(blip, b.name)
        activeBlipHandles[#activeBlipHandles + 1] = blip
    end
end)

local spawnedByMenu = {}

RegisterNuiCallback('spawnEntity', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:spawnentity', function(result)
        cb(result or { success = false })
    end, { entityType = data.entityType, hash = data.hash })
end)

local function parseModel(hash)
    if type(hash) == 'number' then return hash end
    local name = tostring(hash or ''):gsub('%s+', ''):gsub('[\'"`]', '')
    if name == '' then return nil end
    if name:match('^-?%d+$') then return tonumber(name) end
    return joaat(name)
end


local function placeOnGround(entity)
    if entity and entity ~= 0 then
        Citizen.InvokeNative(0x9587913B9E772D29, entity, false)
    end
end


local function loadModel(hash, isObject)
    local model = parseModel(hash)
    if not model then return nil end
    if HasModelLoaded(model) then return model end

    if not isObject and not IsModelValid(model) and not IsModelInCdimage(model) then
        return nil
    end

    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) do
        RequestModel(model)
        if GetGameTimer() > timeout then
            if isObject then return model end
            return nil
        end
        Wait(0)
    end
    return model
end

local function waitForEntity(entity)
    if not entity or entity == 0 then return false end
    local timeout = 50
    while not DoesEntityExist(entity) and timeout > 0 do
        Wait(20)
        timeout = timeout - 1
    end
    return DoesEntityExist(entity)
end

local function groundAt(x, y, z)
    local found, groundZ = GetGroundZAndNormalFor_3dCoord(x, y, z + 50.0)
    if found then return groundZ end
    return z
end

RegisterNetEvent('rsg-adminmenu:client:spawnentity', function(entityType, hash)
    local kind = entityType == 'horse' and 'animal' or entityType
    local model = loadModel(hash, kind == 'prop')
    if not model then
        lib.notify({ title = 'Spawner', description = 'Failed to load model: ' .. tostring(hash), type = 'error' })
        return
    end

    local ped = PlayerPedId()
    local spawnPos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.0)
    local heading = GetEntityHeading(ped)
    local groundZ = groundAt(spawnPos.x, spawnPos.y, spawnPos.z)

    local entity = nil
    if kind == 'wagon' then
        entity = CreateVehicle(model, spawnPos.x, spawnPos.y, groundZ, heading, true, false)
        if waitForEntity(entity) then SetVehicleOnGroundProperly(entity) end
    elseif kind == 'animal' or kind == 'ped' then

        entity = CreatePed(model, spawnPos.x, spawnPos.y, groundZ - 1.0, heading, true, false, 0, 0)
        if waitForEntity(entity) then
            SetRandomOutfitVariation(entity, true)
            EquipMetaPedOutfitPreset(entity, 0, false)
            placeOnGround(entity)
        end
    elseif kind == 'prop' then

        entity = CreateObject(model, spawnPos.x, spawnPos.y, groundZ, true, false, true)
        if not waitForEntity(entity) then
            entity = CreateObject(model, spawnPos.x, spawnPos.y, groundZ, false, false, true)
        end
        if waitForEntity(entity) then
            SetEntityHeading(entity, heading)
            placeOnGround(entity)
            FreezeEntityPosition(entity, true)
        end
    end

    SetModelAsNoLongerNeeded(model)

    if not waitForEntity(entity) then
        lib.notify({ title = 'Spawner', description = 'Model loaded but failed to spawn as a ' .. tostring(kind) .. ' (' .. tostring(hash) .. ' may not be that type of model)', type = 'error' })
    else
        SetEntityAsMissionEntity(entity, true, true)
        spawnedByMenu[entity] = true
        lib.notify({ title = 'Spawner', description = 'Spawned ' .. tostring(kind) .. ': ' .. tostring(hash), type = 'success' })
    end
end)

local function playerPedsAndMounts()
    local protected = {}
    for _, playerId in ipairs(GetActivePlayers()) do
        local playerPed = GetPlayerPed(playerId)
        if playerPed and playerPed ~= 0 then
            protected[playerPed] = true
            if IsPedOnMount(playerPed) then
                local mount = GetMount(playerPed)
                if mount and mount ~= 0 then protected[mount] = true end
            end
            if IsPedInAnyVehicle(playerPed, false) then
                local veh = GetVehiclePedIsIn(playerPed, false)
                if veh and veh ~= 0 then protected[veh] = true end
            end
        end
    end
    return protected
end

local function tryDelete(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    NetworkRequestControlOfEntity(entity)
    local n = 0
    while not NetworkHasControlOfEntity(entity) and n < 10 do
        NetworkRequestControlOfEntity(entity)
        Wait(20)
        n = n + 1
    end
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
    spawnedByMenu[entity] = nil
    return not DoesEntityExist(entity)
end

local function inRadius(entity, origin, radius)
    return #(GetEntityCoords(entity) - origin) <= radius
end

RegisterNuiCallback('clearArea', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:cleararea', function(result)
        cb(result or { success = false })
    end, { radius = data.radius })
end)

RegisterNetEvent('rsg-adminmenu:client:cleararea', function(radius)
    radius = tonumber(radius) or 25.0
    local origin = GetEntityCoords(PlayerPedId())
    local protected = playerPedsAndMounts()
    local removed = 0

   
    for entity in pairs(spawnedByMenu) do
        if DoesEntityExist(entity) and not protected[entity] and inRadius(entity, origin, radius) then
            if tryDelete(entity) then removed = removed + 1 end
        elseif not DoesEntityExist(entity) then
            spawnedByMenu[entity] = nil
        end
    end


    for _, ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped)
            and not protected[ped]
            and not IsPedAPlayer(ped)
            and inRadius(ped, origin, radius)
            and (IsEntityAMissionEntity(ped) or spawnedByMenu[ped])
        then
            if tryDelete(ped) then removed = removed + 1 end
        end
    end


    for _, obj in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(obj)
            and not (IsEntityAttached and IsEntityAttached(obj))
            and inRadius(obj, origin, radius)
            and (IsEntityAMissionEntity(obj) or spawnedByMenu[obj])
        then
            if tryDelete(obj) then removed = removed + 1 end
        end
    end


    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh)
            and not protected[veh]
            and inRadius(veh, origin, radius)
            and (IsEntityAMissionEntity(veh) or spawnedByMenu[veh])
        then
            if tryDelete(veh) then removed = removed + 1 end
        end
    end

    lib.notify({
        title = 'Clear Area',
        description = removed > 0 and ('Removed ' .. removed .. ' entities') or 'Nothing to clear in that radius',
        type = removed > 0 and 'success' or 'inform',
    })
end)
