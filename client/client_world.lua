local RSGCore = exports['rsg-core']:GetCoreObject()

-----------------------------------------------------------------------
-- Coords — fully local, no server round trip needed
-----------------------------------------------------------------------
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

-----------------------------------------------------------------------
-- Teleport locations
-----------------------------------------------------------------------
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

-----------------------------------------------------------------------
-- Blips — CRUD via NUI, live native blips kept in sync via a broadcast
-- event fired by the server whenever the list changes or on connect
-----------------------------------------------------------------------
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
    -- no DoesBlipExist guard — that's another GTA5-only global that doesn't
    -- exist in RDR3 (same story as AddBlipForCoord/SetBlipAsShortRange
    -- earlier); RemoveBlip alone is what's already proven working elsewhere
    -- in this codebase (client.lua), and it's harmless to call on a stale handle
    for _, handle in ipairs(activeBlipHandles) do
        RemoveBlip(handle)
    end
    activeBlipHandles = {}

    for _, b in ipairs(blips or {}) do
        -- RDR3 has no AddBlipForCoord global (that's GTA5-only) — blips are
        -- created from a base style via BlipAddForCoords, then the sprite is
        -- overridden below. BLIP_STYLE_POI is a neutral custom-marker style
        local blip = BlipAddForCoords(GetHashKey('BLIP_STYLE_POI'), b.x + 0.0, b.y + 0.0, b.z + 0.0)
        -- RDR3's SET_BLIP_SPRITE takes a third bool (unlike GTA5's) — without
        -- it the native silently no-ops and the blip renders with no icon
        SetBlipSprite(blip, GetHashKey(b.sprite), true)
        SetBlipScale(blip, (tonumber(b.scale) or 1.0) + 0.0)
        SetBlipName(blip, b.name)
        activeBlipHandles[#activeBlipHandles + 1] = blip
    end
end)

-----------------------------------------------------------------------
-- entity spawner
-----------------------------------------------------------------------
RegisterNuiCallback('spawnEntity', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:spawnentity', function(result)
        cb(result or { success = false })
    end, { entityType = data.entityType, hash = data.hash })
end)

local function loadModel(hash)
    local model = GetHashKey(hash)
    RequestModel(model)
    local attempts = 0
    while not HasModelLoaded(model) and attempts < 200 do
        Wait(10)
        attempts = attempts + 1
    end
    return HasModelLoaded(model) and model or nil
end

RegisterNetEvent('rsg-adminmenu:client:spawnentity', function(entityType, hash)
    local model = loadModel(hash)
    if not model then
        lib.notify({ title = 'Spawner', description = 'Failed to load model: ' .. tostring(hash), type = 'error' })
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local spawnPos = vector3(coords.x + forward.x * 2.0, coords.y + forward.y * 2.0, coords.z)
    local heading = GetEntityHeading(ped)

    local entity = nil
    if entityType == 'wagon' then
        entity = CreateVehicle(model, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)
        if entity and entity ~= 0 then SetVehicleOnGroundProperly(entity) end
    elseif entityType == 'horse' or entityType == 'ped' then
        -- RDR3's CREATE_PED has no leading pedType argument, unlike GTA5's.
        -- Confirmed against this framework's own working spawn code in
        -- rsg-horses/client/horses.lua. The old call here passed a bogus `4`
        -- as the first arg, which the native read as the model hash, shifting
        -- every following argument over by one. That's why this silently
        -- never spawned anything.
        entity = CreatePed(model, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false, 0, 0)
        -- RDR2 peds/horses spawn with no clothing/skin components assigned at
        -- all (unlike GTA5, where the model itself has a default look) — this
        -- is what actually renders them, without it they're just an invisible,
        -- componentless entity. Same call rsg-horses and rsg-npcs both make
        -- unconditionally right after CreatePed.
        if entity and entity ~= 0 then SetRandomOutfitVariation(entity, true) end
    elseif entityType == 'prop' then
        entity = CreateObject(model, spawnPos.x, spawnPos.y, spawnPos.z, true, true, false)
    end

    SetModelAsNoLongerNeeded(model)

    if not entity or entity == 0 then
        lib.notify({ title = 'Spawner', description = 'Model loaded but failed to spawn as a ' .. entityType .. ' (' .. tostring(hash) .. ' may not be that type of model)', type = 'error' })
    else
        lib.notify({ title = 'Spawner', description = 'Spawned ' .. entityType .. ': ' .. tostring(hash), type = 'success' })
    end
end)
