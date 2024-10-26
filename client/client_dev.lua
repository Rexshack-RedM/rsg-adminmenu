local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- main admin base menu
RegisterNetEvent('rsg-adminmenu:client:devoptions', function()

    lib.registerContext({
        id = 'dev_mainmenu',
        title = locale('cl_dev_menu'),
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = {
            {
                title = locale('cl_dev_menu_a'),
                description = locale('cl_dev_menu_b'),
                icon = 'fa-solid fa-horse-head',
                event = 'rsg-adminmenu:client:horseoptions',
                arrow = true
            },
            {
                title = locale('cl_dev_menu_c'),
                description = locale('cl_dev_menu_d'),
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:copycoordsmenu',
                arrow = true
            },
            {
                title = locale('cl_dev_menu_e'),
                description = locale('cl_dev_menu_f'),
                icon = 'fa-solid fa-person-walking',
                event = 'rsg-adminmenu:client:testanimation',
                arrow = true
            },
            {
                title = locale('cl_dev_menu_g'),
                description = locale('cl_dev_menu_h'),
                icon = 'fa-solid fa-hashtag',
                event = 'rsg-adminmenu:client:gethash',
                arrow = true
            },
            {
                title = locale('cl_dev_menu_i'),
                description = locale('cl_dev_menu_j'),
                icon = 'fa-solid fa-door-open',
                event = 'rsg-adminmenu:client:toggledoorid',
                arrow = true
            },
            {
                title = locale('cl_dev_menu_l'),
                description = locale('cl_dev_menu_m'),
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

    local input = lib.inputDialog(locale('cl_dev_126'), {
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
    local input = lib.inputDialog(locale('cl_dev_127'), {
        {
            label = locale('cl_dev_128'),
            description = locale('cl_dev_129'),
            type = 'input',
            required = true,
        },
    })
    if not input then return end

    local hash = joaat(input[1])
    lib.setClipboard(tostring(hash))
    lib.notify({ title = locale('cl_dev_copy'), description = locale('cl_dev_copy_a') ..' '..hash..' ' .. locale('cl_dev_copy_b'), type = 'inform', duration = 5000 })
end)

-- npc/amimal spawner
RegisterNetEvent('rsg-adminmenu:client:spawnped', function()
    local input = lib.inputDialog(locale('cl_dev_spawnped'), {
        {
            label = locale('cl_dev_spawnped1'),
            description = locale('cl_dev_spawnped2'),
            type = 'input',
            required = true,
        },
        {
            label = locale('cl_dev_spawnped3'),
            description = locale('cl_dev_spawnped4'),
            type = 'number',
            default = 0,
            required = true,
        },
        {
            label = locale('cl_dev_spawnped5'),
            description = locale('cl_dev_spawnped6'),
            type = 'number',
            default = 5,
            required = true,
        },
        {
            label = locale('cl_dev_spawnped7'),
            description = locale('cl_dev_spawnped8'),
            type = 'select',
            options = {
                { value = 'true', label = locale('cl_dev_spawnped9') },
                { value = 'false', label = locale('cl_dev_spawnped10') }
            },
            required = true,
        },
        {
            label = locale('cl_dev_spawnped11'),
            description = locale('cl_dev_spawnped12'),
            type = 'select',
            options = {
                { value = 'true', label = locale('cl_dev_spawnped9') },
                { value = 'false', label = locale('cl_dev_spawnped10') }
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