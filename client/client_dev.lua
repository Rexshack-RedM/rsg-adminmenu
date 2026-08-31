local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- horse options
RegisterNuiCallback('getHorseOptions', function(_, cb)
    local options = {}
    for i = 1, #Config.AdminHorse do
        options[#options + 1] = { value = Config.AdminHorse[i].horsehash, label = Config.AdminHorse[i].horsename }
    end
    cb(options)
end)

RegisterNuiCallback('spawnHorse', function(data, cb)
    TriggerEvent('rsg-adminmenu:client:spawnhorse', tonumber(data.hash))
    cb({ success = true })
end)

RegisterNuiCallback('getEntityHash', function(data, cb)
    local hash = joaat(data.name)
    lib.setClipboard(tostring(hash))
    cb({ hash = tostring(hash) })
end)

RegisterNuiCallback('spawnPed', function(data, cb)
    local hash = joaat(data.model)
    TriggerEvent('rsg-adminmenu:client:dospawnped', hash, tonumber(data.outfit) or 0, tonumber(data.distance) or 5,
        data.freeze and 'true' or 'false', data.dead and 'true' or 'false')
    cb({ success = true })
end)

-- spawn horse / warp player / set networked
RegisterNetEvent('rsg-adminmenu:client:spawnhorse', function(HorseHash)
    local pos = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 3.0, 0.0)
    local heading = GetEntityHeading(cache.ped)
    local hash = HorseHash
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end

    local horsePed = CreatePed(hash, pos.x, pos.y, pos.z -1, heading, true, false)
    TaskMountAnimal(cache.ped, horsePed, 10000, -1, 1.0, 1, 0, 0)
    SetRandomOutfitVariation(horsePed, true)
    EnableAttributeOverpower(horsePed, 0, 5000.0) -- health overpower
    EnableAttributeOverpower(horsePed, 1, 5000.0) -- stamina overpower
    EnableAttributeOverpower(horsePed, 0, 5000.0) -- set health with overpower
    EnableAttributeOverpower(horsePed, 1, 5000.0) -- set stamina with overpower
    SetPlayerOwnsMount(cache.ped, horsePed)
    ApplyShopItemToPed(horsePed, -447673416, true, true, true) -- add saddle
    NetworkSetEntityInvisibleToNetwork(horsePed, true)
end)

-- npc/amimal spawner
RegisterNetEvent('rsg-adminmenu:client:dospawnped', function(hash, outfit, distance, freeze, dead)
    local playerCoords = GetEntityCoords(cache.ped)
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end
    spawnped = CreatePed(hash, playerCoords.x + distance, playerCoords.y + distance, playerCoords.z, true, true, true)
    EquipMetaPedOutfitPreset(spawnped, outfit, false)
    if dead == 'true' then
        SetEntityHealth(spawnped, 0)
    end
    if freeze == 'true' then
        FreezeEntityPosition(spawnped, true)
    end
    SetModelAsNoLongerNeeded(spawnped)
end)
