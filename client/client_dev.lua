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
                title = Lang:t('lang_70'),
                description = Lang:t('lang_71'),
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:vector2',
                arrow = true
            },
            {
                title = Lang:t('lang_72'),
                description = Lang:t('lang_73'),
                icon = Lang:t('lang_0')'fa-solid fa-clipboard',
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
