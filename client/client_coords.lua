local RSGCore = exports['rsg-core']:GetCoreObject()

-- Variable global para almacenar la lista de coordenadas
local coordsList = {}
local printListEnabled = false
lib.locale()

RegisterNetEvent('rsg-adminmenu:client:copycoordsmenu', function()

    lib.registerContext({
        id = 'coords_mainmenu',
        title = locale('cl_coords_menu'),
        menu = 'dev_mainmenu',
        onBack = function() end,
        options = {
            {
                title = locale('cl_coords_70'),
                description = locale('cl_coords_71'),
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:vector2',
                arrow = true
            },
            {
                title = locale('cl_coords_72'),
                description = locale('cl_coords_73'),
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:vector3',
                arrow = true
            },
            {
                title = locale('cl_coords_74'),
                description = locale('cl_coords_75'),
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:vector4',
                arrow = true
            },
            {
                title = locale('cl_coords_76'),
                description = locale('cl_coords_77'),
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:copyheading',
                arrow = true
            },
            {
                title = locale('cl_coords_print_list'),
                description = locale('cl_coords_print_list_a'),
                icon = 'fa-solid fa-list',
                event = 'rsg-adminmenu:client:printlist_on',
                arrow = true
            },
            {
                title = locale('cl_coords_print_full'),
                description = locale('cl_coords_print_full_a'),
                icon = 'fa-solid fa-list',
                event = 'rsg-adminmenu:client:printlist_full',
                arrow = true
            },
        }
    })
    lib.showContext('coords_mainmenu')

end)

-- Copy Coordinates
local function CopyCoords(data)
    local coords = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)
    local formats = { vector2 = "%.2f, %.2f", vector3 = "%.2f, %.2f, %.2f", vector4 = "%.2f, %.2f, %.2f, %.2f", heading = "%.2f" }
    local format = formats[data]

    local values = {coords.x, coords.y, coords.z, heading}

    if printListEnabled then
        local coordString = string.format(format, table.unpack(values, 1, #values))
        table.insert(coordsList, coordString)
    else
        lib.setClipboard(string.format(format, table.unpack(values, 1, #format)))
    end
end

RegisterNetEvent('rsg-adminmenu:client:vector2', function()
    CopyCoords("vector2")
    lib.notify({ title = locale('cl_coords_78'), description = locale('cl_coords_79'), type = 'inform' })
end)

RegisterNetEvent('rsg-adminmenu:client:vector3', function()
    CopyCoords("vector3")
    lib.notify({ title = locale('cl_coords_78'), description = locale('cl_coords_80'), type = 'inform' })
end)

RegisterNetEvent('rsg-adminmenu:client:vector4', function()
    CopyCoords("vector4")
    lib.notify({ title = locale('cl_coords_78'), description = locale('cl_coords_81'), type = 'inform' })
end)

RegisterNetEvent('rsg-adminmenu:client:copyheading', function()
    CopyCoords("heading")
    lib.notify({ title = locale('cl_coords_82'), description = locale('cl_coords_83'), type = 'inform' })
end)

----------------------
-- print list
----------------------
RegisterNetEvent('rsg-adminmenu:client:printlist_on', function()
    printListEnabled = true
    coordsList = {}
    lib.notify({ title = locale('cl_coords_printlist'), description = locale('cl_coords_printlist_a'), type = 'inform' })
end)

RegisterNetEvent('rsg-adminmenu:client:printlist_full', function()
    printListEnabled = false
    if #coordsList > 0 then
        local listString = table.concat(coordsList, '\n')
        lib.setClipboard(listString)
        print(listString)
        lib.notify({ title = locale('cl_coords_printlist'), description = locale('cl_coords_printlist_b'), type = 'inform' })
    else
        lib.notify({ title = locale('cl_coords_printlist'), description = locale('cl_coords_printlist_c'), type = 'inform' })
    end
end)