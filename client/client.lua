local RSGCore = exports['rsg-core']:GetCoreObject()

-- main admin base menu
RegisterNetEvent('rsg-adminmenu:client:openadminmenu', function(data)

    lib.registerContext({
        id = 'admin_mainmenu',
        title = 'Admin Menu',
        options = {
            {
                title = 'Title',
                description = 'description',
                icon = 'fa-solid fa-fingerprint',
            },
        }
    })
    lib.showContext('admin_mainmenu')

end)
