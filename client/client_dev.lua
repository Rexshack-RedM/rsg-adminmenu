local RSGCore = exports['rsg-core']:GetCoreObject()

-- main admin base menu
RegisterNetEvent('rsg-adminmenu:client:devoptions', function()

    lib.registerContext({
        id = 'dev_mainmenu',
        title = 'Developer Menu',
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = {
            {
                title = 'Copy Vector 2',
                description = 'copy vector2 coords',
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:vector2',
                arrow = true
            },
            {
                title = 'Copy Vector 3',
                description = 'copy vector3 coords',
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:vector3',
                arrow = true
            },
            {
                title = 'Copy Vector 4',
                description = 'copy vector4 coords',
                icon = 'fa-solid fa-clipboard',
                event = 'rsg-adminmenu:client:vector4',
                arrow = true
            },
            {
                title = 'Copy Heading',
                description = 'copy heading',
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
    lib.notify({ title = 'Coords Copied', description = 'vector2 coords copied to the clipboard', type = 'inform' })
end)

RegisterNetEvent('rsg-adminmenu:client:vector3', function()
    CopyCoords("vector3")
    lib.notify({ title = 'Coords Copied', description = 'vector3 coords copied to the clipboard', type = 'inform' })
end)

RegisterNetEvent('rsg-adminmenu:client:vector4', function()
    CopyCoords("vector4")
    lib.notify({ title = 'Coords Copied', description = 'vector4 coords copied to the clipboard', type = 'inform' })
end)

RegisterNetEvent('rsg-adminmenu:client:copyheading', function()
    CopyCoords("heading")
    lib.notify({ title = 'Heading Copied', description = 'heading copied to the clipboard', type = 'inform' })
end)
