local RSGCore = exports['rsg-core']:GetCoreObject()

-- main admin base menu
RegisterNetEvent('rsg-adminmenu:client:openadminmenu', function()

    lib.registerContext({
        id = 'admin_mainmenu',
        title = 'Admin Menu',
        options = {
            {
                title = 'Admin Options',
                description = 'Misc. Admin Options',
                icon = 'fa-solid fa-fingerprint',
                event = 'rsg-adminmenu:client:adminoptions',
                arrow = true
            },
            {
                title = 'Online Players',
                description = 'View List Of Players',
                icon = 'fa-solid fa-fingerprint',
                event = 'rsg-adminmenu:client:playersoptions',
                arrow = true
            },
            {
                title = 'Manage Server',
                description = 'Misc. Server Options',
                icon = 'fa-solid fa-fingerprint',
                event = 'rsg-adminmenu:client:serveroptions',
                arrow = true
            },
            {
                title = 'Developer Options',
                description = 'Misc. Dev Options',
                icon = 'fa-solid fa-fingerprint',
                event = 'rsg-adminmenu:client:devoptions',
                arrow = true
            },
        }
    })
    lib.showContext('admin_mainmenu')

end)

-- admin options menu
RegisterNetEvent('rsg-adminmenu:client:adminoptions', function()

    lib.registerContext({
        id = 'admin_optionsmenu',
        title = 'Admin Options Menu',
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = {
            {
                title = 'title',
                description = 'description',
                icon = 'fa-solid fa-fingerprint',
                event = '',
                arrow = true
            },
        }
    })
    lib.showContext('admin_optionsmenu')

end)

-- players options menu
RegisterNetEvent('rsg-adminmenu:client:playersoptions', function()

    lib.registerContext({
        id = 'players_optionssmenu',
        title = 'Players Options Menu',
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = {
            {
                title = 'title',
                description = 'description',
                icon = 'fa-solid fa-fingerprint',
                event = '',
                arrow = true
            },
        }
    })
    lib.showContext('players_optionssmenu')

end)

-- server options menu
RegisterNetEvent('rsg-adminmenu:client:serveroptions', function()

    lib.registerContext({
        id = 'server_optionssmenu',
        title = 'Server Options Menu',
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = {
            {
                title = 'title',
                description = 'description',
                icon = 'fa-solid fa-fingerprint',
                event = '',
                arrow = true
            },
        }
    })
    lib.showContext('server_optionssmenu')

end)

-- server options menu
RegisterNetEvent('rsg-adminmenu:client:devoptions', function()

    lib.registerContext({
        id = 'dev_optionssmenu',
        title = 'Developer Options Menu',
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = {
            {
                title = 'title',
                description = 'description',
                icon = 'fa-solid fa-fingerprint',
                event = '',
                arrow = true
            },
        }
    })
    lib.showContext('dev_optionssmenu')

end)
