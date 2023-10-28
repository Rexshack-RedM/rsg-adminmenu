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
                title = 'Spawn Admin Horse',
                description = 'spawn a admin horse',
                icon = 'fa-solid fa-horse-head',
                event = 'rsg-adminmenu:client:horseoptions',
                arrow = true
            },
            {
                title = Lang:t('lang_70'),
                description = Lang:t('lang_71'),
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:vector2',
                arrow = true
            },
            {
                title = Lang:t('lang_72'),
                description = Lang:t('lang_73'),
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:vector3',
                arrow = true
            },
            {
                title = Lang:t('lang_74'),
                description = Lang:t('lang_75'),
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:vector4',
                arrow = true
            },
            {
                title = Lang:t('lang_76'),
                description = Lang:t('lang_77'),
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:copyheading',
                arrow = true
            },
        }
    })
    lib.showContext('dev_mainmenu')

end)

-- Copy Coordinates
local function CopyCoords(data)
    local coords = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)
    local formats = { vector2 = "%.2f, %.2f", vector3 = "%.2f, %.2f, %.2f", vector4 = "%.2f, %.2f, %.2f, %.2f", heading = "%.2f" }
    local format = formats[data]

    local values = {coords.x, coords.y, coords.z, heading}
    lib.setClipboard(string.format(format, table.unpack(values, 1, #format)))
end

RegisterNetEvent('rsg-adminmenu:client:vector2', function()
    CopyCoords("vector2")
    lib.notify({ title = Lang:t('lang_78'), description = Lang:t('lang_79'), type = 'inform' })
end)

RegisterNetEvent('rsg-adminmenu:client:vector3', function()
    CopyCoords("vector3")
    lib.notify({ title = Lang:t('lang_78'), description = Lang:t('lang_80'), type = 'inform' })
end)

RegisterNetEvent('rsg-adminmenu:client:vector4', function()
    CopyCoords("vector4")
    lib.notify({ title = Lang:t('lang_78'), description = Lang:t('lang_81'), type = 'inform' })
end)

RegisterNetEvent('rsg-adminmenu:client:copyheading', function()
    CopyCoords("heading")
    lib.notify({ title = Lang:t('lang_82'), description = Lang:t('lang_83'), type = 'inform' })
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

    local input = lib.inputDialog("Spawn Admin Horse", {
        { type = 'select', options = option, required = true, default = 'Arabian White' }
    })
    if not input then return end
    
    TriggerEvent('rsg-adminmenu:client:spawnhorse', input[1])

end)

-- spawn horse / warp player / set networked
RegisterNetEvent('rsg-adminmenu:client:spawnhorse', function(HorseHash)
    local pos = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 3.0, 0.0)
    local heading = GetEntityHeading(PlayerPedId())
    local ped = PlayerPedId()
    local hash = HorseHash
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end

    local horsePed = CreatePed(hash, pos.x, pos.y, pos.z -1, heading, true, false)
    TaskMountAnimal(ped, horsePed, 10000, -1, 1.0, 1, 0, 0)
    Citizen.InvokeNative(0x283978A15512B2FE, horsePed, true)
    EnableAttributeOverpower(horsePed, 0, 5000.0) -- health overpower
    EnableAttributeOverpower(horsePed, 1, 5000.0) -- stamina overpower
    Citizen.InvokeNative(0xF6A7C08DF2E28B28, horsePed, 0, 5000.0) -- set health with overpower
    Citizen.InvokeNative(0xF6A7C08DF2E28B28, horsePed, 1, 5000.0) -- set stamina with overpower
    Citizen.InvokeNative(0xE6D4E435B56D5BD0, ped, horsePed)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, -447673416, true, true, true) -- add saddle
    NetworkSetEntityInvisibleToNetwork(horsePed, true)
end)
