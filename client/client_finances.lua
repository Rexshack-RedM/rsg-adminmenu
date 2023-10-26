local RSGCore = exports['rsg-core']:GetCoreObject()

-- finances players menu
RegisterNetEvent('rsg-adminmenu:client:playersfinances', function()
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getplayers', function(players)
        local options = {}
        for k, v in pairs(players) do
            options[#options + 1] = {
                title = 'ID: '..k..' | '..v.name,
                description = '',
                icon = 'fa-solid fa-circle-user',
                event = 'rsg-adminmenu:client:financesoptions',
                args = { name = v.name, player = k },
                arrow = true,
            }
        end
        lib.registerContext({
            id = 'finances_menu',
            title = 'Player Finances',
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

    lib.registerContext({
        id = 'finances_optionsmenu',
        title = 'Finances Options Menu',
        menu = 'finances_menu',
        onBack = function() end,
        options = {
            {
                title = 'Give Money',
                description = 'give money to player',
                icon = 'fa-solid fa-user-plus',
                event = 'rsg-adminmenu:client:givemoney',
                args = { id = data.player, name = data.name },
                arrow = true
            },
            {
                title = 'Remove Money',
                description = 'remove money from player',
                icon = 'fa-solid fa-user-minus',
                event = 'rsg-adminmenu:client:removemoney',
                args = { id = data.player, name = data.name },
                arrow = true
            },
        }
    })
    lib.showContext('finances_optionsmenu')

end)

-- give money to player (bank, cash, bloodmoney)
RegisterNetEvent('rsg-adminmenu:client:givemoney', function(data)

    local input = lib.inputDialog(data.name, {
        {
            label = 'Type',
            description = 'chose the type to give to the player',
            type = 'select',
            options = {
                {
                    label = 'Bank', value = 'bank'
                },
                {
                    label = 'Cash', value = 'cash'
                },
                {
                    label = 'Blood Money', value = 'bloodmoney'
                },
            },
            required = true,
        },
        { 
            label = 'Amount',
            description = 'how much do you want to give?',
            type = 'number',
            required = true,
        },
    })
    
    if not input then
        return
    end

    TriggerServerEvent('rsg-adminmenu:server:financeadd', data.id, input[1], input[2])

end)

-- remove money from player (bank, cash, bloodmoney)
RegisterNetEvent('rsg-adminmenu:client:removemoney', function(data)

    local input = lib.inputDialog(data.name, {
        {
            label = 'Type',
            description = 'chose the type to remove from the player',
            type = 'select',
            options = {
                {
                    label = 'Bank', value = 'bank'
                },
                {
                    label = 'Cash', value = 'cash'
                },
                {
                    label = 'Blood Money', value = 'bloodmoney'
                },
            },
            required = true,
        },
        { 
            label = 'Amount',
            description = 'how much do you want to remove?',
            type = 'number',
            required = true,
        },
    })
    
    if not input then
        return
    end

    TriggerServerEvent('rsg-adminmenu:server:financeremove', data.id, input[1], input[2])

end)
