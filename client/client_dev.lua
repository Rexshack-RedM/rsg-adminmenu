local RSGCore = exports['rsg-core']:GetCoreObject()

-- main admin base menu
RegisterNetEvent('rsg-adminmenu:client:devoptions', function()

    lib.registerContext({
        id = 'dev_mainmenu',
        title = Lang:t('lang_69'),
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = {
            {
                title = Lang:t('lang_41'),
                description = Lang:t('lang_125'),
                icon = 'fa-solid fa-horse-head',
                event = 'rsg-adminmenu:client:horseoptions',
                arrow = true
            },
            {
                title = 'Copy Coords Menu',
                description = 'copy coords to clipboard',
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:copycoordsmenu',
                arrow = true
            },
            {
                title = 'Animation Tester',
                description = 'test animations',
                icon = 'fa-solid fa-person-walking',
                event = 'rsg-adminmenu:client:testanimation',
                arrow = true
            },
            {
                title = 'Entity Hash',
                description = 'get entity hash',
                icon = 'fa-solid fa-hashtag',
                event = 'rsg-adminmenu:client:gethash',
                arrow = true
            },
            {
                title = 'Toggle Door IDs on/off',
                description = 'used to get door ids',
                icon = 'fa-solid fa-door-open',
                event = 'rsg-adminmenu:client:toggledoorid',
                arrow = true
            },
            {
                title = 'Ped Sawner',
                description = 'used to spawn npc/animals',
                icon = 'fa-solid fa-paw',
                event = 'rsg-adminmenu:client:spawnped',
                arrow = true
            },
        }
    })
    lib.showContext('dev_mainmenu')

end)

-- spawn admin horse
RegisterNetEvent('rsg-adminmenu:client:horseoptions', function()
    local option = {}
    for i = 1, #Config.AdminHorse do
        local name = Config.AdminHorse[i].horsename
        local hash = Config.AdminHorse[i].horsehash
        local content = { value = hash, label = name }
        option[#option + 1] = content
    end

    local input = lib.inputDialog(Lang:t('lang_126'), {
        { type = 'select', options = option, required = true, default = 'Arabian White' }
    })
    if not input then return end

    TriggerEvent('rsg-adminmenu:client:spawnhorse', input[1])

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

-- get entity hash
RegisterNetEvent('rsg-adminmenu:client:gethash', function()
    local input = lib.inputDialog('Get Entity Hash', {
        {
            label = 'entity name',
            description = 'example : PROVISION_ALLIGATOR_SKIN',
            type = 'input',
            required = true,
        },
    })
    if not input then return end

    local hash = joaat(input[1])
    lib.setClipboard(tostring(hash))
    lib.notify({ title = 'Entity Hash Copied', description = 'entity hash of '..hash..' has been copied to your clipboard', type = 'inform', duration = 5000 })
end)

-- npc/amimal spawner
RegisterNetEvent('rsg-adminmenu:client:spawnped', function()
    local input = lib.inputDialog('Spawn Ped/Animal', {
        {
            label = 'ped name',
            description = 'example : mp_a_c_wolf_01',
            type = 'input',
            required = true,
        },
        {
            label = 'outfit',
            description = 'outfit number for ped/animal',
            type = 'number',
            default = 0,
            required = true,
        },
        {
            label = 'distance',
            description = 'spawn distrance away from you',
            type = 'number',
            default = 5,
            required = true,
        },
        {
            label = 'freeze',
            description = 'freeze npc/animal on spawn',
            type = 'select',
            options = {
                { value = 'true', label = 'True' },
                { value = 'false', label = 'False' }
            },
            required = true,
        },
        {
            label = 'spawn dead',
            description = 'spawn npc/animal dead',
            type = 'select',
            options = {
                { value = 'true', label = 'True' },
                { value = 'false', label = 'False' }
            },
            required = true,
        },
    })
    if not input then return end
    local hash = joaat(input[1])
    TriggerEvent('rsg-adminmenu:client:dospawnped', hash, input[2], input[3], input[4], input[5])
end)

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
