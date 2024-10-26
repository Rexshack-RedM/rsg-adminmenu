local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- finances players menu
RegisterNetEvent('rsg-adminmenu:client:playersfinances', function()
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getplayers', function(players)
        local options = {}
        for k, v in pairs(players) do
            options[#options + 1] = {
                title = locale('cl_finan_19') .. ' ' .. v.id .. ' | ' .. v.name,
                icon = 'fa-solid fa-circle-user',
                event = 'rsg-adminmenu:client:financesoptions',
                args = { name = v.name, player = v.id },
                arrow = true,
            }
        end
        lib.registerContext({
            id = 'finances_menu',
            title = locale('cl_finan_menu'),
            menu = 'admin_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('finances_menu')
    end)
end)

-- finances options menu
RegisterNetEvent('rsg-adminmenu:client:financesoptions', function(data)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getPlayerData', function(result)
        lib.registerContext({
            id = 'finances_optionsmenu',
            title = locale('cl_finan_90'),
            menu = 'finances_menu',
            onBack = function() end,
            options = {
            {
                title = locale('cl_finan_122')..result.bank,
                description = locale('cl_finan_119'),
                readOnly = true
            },
            {
                title = locale('cl_finan_122_a')..result.valbank,
                description = locale('cl_finan_119'),
                readOnly = true
            },
            {
                title = locale('cl_finan_122_b')..result.rhobank,
                description = locale('cl_finan_119'),
                readOnly = true
            },
            {
                title = locale('cl_finan_122_c')..result.blkbank,
                description = locale('cl_finan_119'),
                readOnly = true
            },
            {
                title = locale('cl_finan_122_d')..result.armbank,
                description = locale('cl_finan_119'),
                readOnly = true
            },
            {
                title = locale('cl_finan_123')..result.cash,
                description = locale('cl_finan_120'),
                readOnly = true
            },
            {
                title = locale('cl_finan_123_a')..result.bloodmoney,
                description = locale('cl_finan_121'),
                readOnly = true
            },
            {
                title = locale('cl_finan_91'),
                description = locale('cl_finan_92'),
                icon = 'fa-solid fa-user-plus',
                iconColor = 'green',
                event = 'rsg-adminmenu:client:givemoney',
                args = { id = data.player, name = data.name },
                arrow = true
            },
            {
                title = locale('cl_finan_93'),
                description = locale('cl_finan_94'),
                icon = 'fa-solid fa-user-minus',
                iconColor = 'red',
                event = 'rsg-adminmenu:client:removemoney',
                args = { id = data.player, name = data.name },
                arrow = true
            },
            }
        })
        lib.showContext('finances_optionsmenu')
    end, data.player)
end)

-- give money to player (bank, cash, bloodmoney)
RegisterNetEvent('rsg-adminmenu:client:givemoney', function(data)
    local input = lib.inputDialog(data.name, {
        {
            label = locale('cl_finan_95'),
            description = locale('cl_finan_96'),
            type = 'select',
            options = {
                { label = locale('cl_finan_2'), value = 'bank' },
                { label = locale('cl_finan_2a'), value = 'valbank' },
                { label = locale('cl_finan_2b'), value = 'rhobank' },
                { label = locale('cl_finan_2c'), value = 'blkbank' },
                { label = locale('cl_finan_2d'), value = 'armbank' },
                { label = locale('cl_finan_3'), value = 'cash' },
                { label = locale('cl_finan_3a'), value = 'bloodmoney' },
            },
            required = true,
        },
        {
            label = locale('cl_finan_97'),
            description = locale('cl_finan_98'),
            type = 'number',
            required = true,
        },
    })

    if not input then return end
    TriggerServerEvent('rsg-adminmenu:server:financeadd', data.id, input[1], input[2])

end)

-- remove money from player (bank, cash, bloodmoney)
RegisterNetEvent('rsg-adminmenu:client:removemoney', function(data)

    local input = lib.inputDialog(data.name, {
        {
            label = locale('cl_finan_95'),
            description = locale('cl_finan_99'),
            type = 'select',
            options = {
                { label = locale('cl_finan_2'), value = 'bank' },
                { label = locale('cl_finan_2a'), value = 'valbank' },
                { label = locale('cl_finan_2b'), value = 'rhobank' },
                { label = locale('cl_finan_2c'), value = 'blkbank' },
                { label = locale('cl_finan_2d'), value = 'armbank' },
                { label = locale('cl_finan_3'), value = 'cash' },
                { label = locale('cl_finan_3a'), value = 'bloodmoney' },
            },
            required = true,
        },
        {
            label = locale('cl_finan_97'),
            description = locale('cl_finan_115'),
            type = 'number',
            required = true,
        },
    })

    if not input then return end
    TriggerServerEvent('rsg-adminmenu:server:financeremove', data.id, input[1], input[2])

end)