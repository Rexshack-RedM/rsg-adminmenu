local RSGCore = exports['rsg-core']:GetCoreObject()

-- main admin base menu
RegisterNetEvent('rsg-adminmenu:client:openadminmenu', function()

    lib.registerContext({
        id = 'admin_mainmenu',
        title = Lang:t('lang_0'),
        options = {
            {
                title = Lang:t('lang_0'),
                description = Lang:t('lang_1'),
                icon = 'fa-solid fa-user-secret',
                event = 'rsg-adminmenu:client:adminoptions',
                arrow = true
            },
            {
                title = Lang:t('lang_2'),
                description = Lang:t('lang_3'),
                icon = 'fa-solid fa-user',
                event = 'rsg-adminmenu:client:playersoptions',
                arrow = true
            },
            {
                title = Lang:t('lang_88'),
                description = Lang:t('lang_89'),
                icon = 'fa-solid fa-money-bill',
                event = 'rsg-adminmenu:client:playersfinances',
                arrow = true
            },
            {
                title = Lang:t('lang_4'),
                description = Lang:t('lang_5'),
                icon = 'fa-regular fa-face-grin-squint-tears',
                event = 'rsg-adminmenu:client:playerstroll',
                arrow = true
            },
            {
                title = Lang:t('lang_6'),
                description = Lang:t('lang_7'),
                icon = 'fa-solid fa-server',
                event = 'rsg-adminmenu:client:serveroptions',
                arrow = true
            },
            {
                title = Lang:t('lang_8'),
                description = Lang:t('lang_9'),
                icon = 'fa-solid fa-code',
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
        title = Lang:t('lang_10'),
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = {
            {
                title = Lang:t('lang_11'),
                description = Lang:t('lang_12'),
                icon = 'fa-solid fa-up-down-left-right',
                event = 'RSGCore:Command:GoToMarker',
                arrow = true
            },
            {
                title = Lang:t('lang_13'),
                description = Lang:t('lang_14'),
                icon = 'fa-solid fa-heart-pulse',
                event = 'rsg-medic:client:playerRevive',
                arrow = true
            },
            {
                title = Lang:t('lang_15'),
                description = Lang:t('lang_16'),
                icon = 'fa-solid fa-ghost',
                event = 'rsg-adminmenu:client:goinvisible',
                arrow = true
            },
            {
                title = Lang:t('lang_17'),
                description = Lang:t('lang_18'),
                icon = 'fa-solid fa-book-bible',
                event = 'rsg-adminmenu:client:godmode',
                arrow = true
            },
        }
    })
    lib.showContext('admin_optionsmenu')

end)

-----------------------------------------------------------------------------------
-- player options
-----------------------------------------------------------------------------------

-- players options menu
RegisterNetEvent('rsg-adminmenu:client:playersoptions', function()
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getplayers', function(players)
        local options = {}
        for k, v in pairs(players) do
            options[#options + 1] = {
                title = Lang:t('lang_19') ..k..' | '..v.name,
                description = Lang:t('lang_20'),
                icon = 'fa-solid fa-circle-user',
                event = 'rsg-adminmenu:client:playermenu',
                args = { name = v.name, player = k },
                arrow = true,
            }
        end
        lib.registerContext({
            id = 'players_optionssmenu',
            title = Lang:t('lang_21'),
            menu = 'admin_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('players_optionssmenu')
    end)
end)

-----------------------------------------------------------------------------------

-- player menu
RegisterNetEvent('rsg-adminmenu:client:playermenu', function(data)

    lib.registerContext({
        id = 'player_menu',
        title = data.name,
        menu = 'players_optionssmenu',
        onBack = function() end,
        options = {
            {
                title = Lang:t('lang_22'),
                description = Lang:t('lang_23'),
                icon = 'fa-solid fa-briefcase-medical',
                serverEvent = 'rsg-adminmenu:server:playerrevive',
                args = { id = data.player },
                arrow = true
            },
            {
                title = Lang:t('lang_24'),
                description = Lang:t('lang_25'),
                icon = 'fa-solid fa-box',
                serverEvent = 'rsg-adminmenu:server:openinventory',
                args = { id = data.player },
                arrow = true
            },
            {
                title = Lang:t('lang_26'),
                description = Lang:t('lang_27'),
                icon = 'fa-solid fa-socks',
                event = 'rsg-adminmenu:client:kickplayer',
                args = { id = data.player, name = data.name },
                arrow = true
            },
            {
                title = Lang:t('lang_28'),
                description = Lang:t('lang_29') ,
                icon = 'fa-solid fa-ban',
                event = 'rsg-adminmenu:client:banplayer',
                args = { id = data.player, name = data.name },
                arrow = true
            },
            {
                title = Lang:t('lang_30'),
                description = Lang:t('lang_31'),
                icon = 'fa-solid fa-location-dot',
                serverEvent = 'rsg-adminmenu:server:gotoplayer',
                args = { id = data.player },
                arrow = true
            },
            {
                title = Lang:t('lang_32'),
                description = Lang:t('lang_33'),
                icon = 'fa-solid fa-hand',
                serverEvent = 'rsg-adminmenu:server:bringplayer',
                args = { id = data.player },
                arrow = true
            },
            {
                title = Lang:t('lang_34'),
                description = Lang:t('lang_35'),
                icon = 'fa-solid fa-snowflake',
                serverEvent = 'rsg-adminmenu:server:freezeplayer',
                args = { id = data.player, name = data.name },
                arrow = true
            },
            {
                title = Lang:t('lang_36'),
                description = Lang:t('lang_37'),
                icon = 'fa-solid fa-eye',
                serverEvent = 'rsg-adminmenu:server:spectateplayer',
                args = { id = data.player },
                arrow = true
            },
        }
    })
    lib.showContext('player_menu')

end)

-- server options menu
RegisterNetEvent('rsg-adminmenu:client:serveroptions', function()

    lib.registerContext({
        id = 'server_optionssmenu',
        title = Lang:t('lang_38'),
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = {
            {
                title = Lang:t('lang_39'),
                description = Lang:t('lang_40'),
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
        title = Lang:t('lang_41'),
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = {
            {
                title = Lang:t('lang_39'),
                description = Lang:t('lang_40'),
                icon = 'fa-solid fa-fingerprint',
                event = '',
                arrow = true
            },
        }
    })
    lib.showContext('dev_optionssmenu')

end)

-------------------------------------------------------------------
-- go invisible
-------------------------------------------------------------------
local invisible = false
RegisterNetEvent('rsg-adminmenu:client:goinvisible', function()
    TriggerServerEvent('rsg-logs:server:CreateLog', 'admin', 'Admin Options', 'red', GetPlayerName() .. ' toggled > INVISIBLE MODE <')
    if invisible then
        SetEntityVisible(PlayerPedId(), true)
        invisible = false
        lib.notify({ title = Lang:t('lang_42'), description = Lang:t('lang_43'), type = 'inform' })
    else
        SetEntityVisible(PlayerPedId(), false)
        invisible = true
        lib.notify({ title = Lang:t('lang_44'), description = Lang:t('lang_45'), type = 'inform' })
    end
end)

-------------------------------------------------------------------
-- god mode
-------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:godmode', function()
    godmode = not godmode
    if godmode == true then
        lib.notify({ title = Lang:t('lang_46'), description = Lang:t('lang_47'), type = 'inform' })
    end
    TriggerServerEvent('rsg-logs:server:CreateLog', 'admin', 'Admin Options', 'red', GetPlayerName() .. ' toggled > GODMODE <')
    if godmode then
        while godmode do
            Wait(0)
            SetPlayerInvincible(PlayerPedId(), true)
        end
        SetPlayerInvincible(PlayerPedId(), false)
        lib.notify({ title = Lang:t('lang_48'), description = Lang:t('lang_49'), type = 'inform' })
    end
end)

-------------------------------------------------------------------
-- open player inventory
-------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:openinventory', function(targetPed)
    TriggerServerEvent("inventory:server:OpenInventory", "otherplayer", targetPed)
end)

-------------------------------------------------------------------
-- kick player reason
-------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:kickplayer', function(data)
    local input = lib.inputDialog(Lang:t('lang_50')..data.name, {
        { 
            label = Lang:t('lang_51'),
            type = 'input',
            required = true,
        },
    })
    if not input then return end

    TriggerServerEvent('rsg-adminmenu:server:kickplayer', data.id, input[1])

end)

-------------------------------------------------------------------
-- ban player reason
-------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:banplayer', function(data)
    local input = lib.inputDialog(Lang:t('lang_52')..data.name, {
        { 
            label = Lang:t('lang_53'),
            type = 'select',
                options = {
                    { value = "permanent", label = "Permanent" },
                    { value = "temporary", label = "Temporary" },
                },
            required = true,
        },
        { 
            label = Lang:t('lang_54'),
            type = 'select',
                options = {
                    { value = '3600', label = Lang:t('lang_55') },
                    { value = '21600', label = Lang:t('lang_56') },
                    { value = '43200', label = Lang:t('lang_57') },
                    { value = '86400', label = Lang:t('lang_58') },
                    { value = '259200', label = Lang:t('lang_59') },
                    { value = '604800', label = Lang:t('lang_60') },
                    { value = '2678400', label = Lang:t('lang_61') },
                    { value = '8035200', label = Lang:t('lang_62') },
                    { value = '16070400', label = Lang:t('lang_63') },
                    { value = '32140800', label = Lang:t('lang_64') },
                    { value = '99999999999', label = Lang:t('lang_65') },
                },
            required = true,
        },
        { 
            label = Lang:t('lang_51'),
            type = 'input',
            required = true,
        }
    })

    if not input then return end

    -- permanent ban
    if input[1] == 'permanent' then
        TriggerServerEvent('rsg-adminmenu:server:banplayer', data.id, '99999999999', input[3])
        lib.notify({ title = Lang:t('lang_66'), description = data.name..Lang:t('lang_67'), type = 'inform' })
    end
    -- temporary ban
    if input[1] == 'temporary' then
        TriggerServerEvent('rsg-adminmenu:server:banplayer', data.id, input[2], input[3])
        lib.notify({ title = Lang:t('lang_66'), description = data.name..Lang:t('lang_68'), type = 'inform' })
    end
end)

-------------------------------------------------------------------
-- spectate player
-------------------------------------------------------------------

local lastSpectateCoord = nil
local isSpectating = false

RegisterNetEvent('rsg-adminmenu:server:spectateplayer', function(targetPed)
    local myPed = PlayerPedId()
    local targetplayer = GetPlayerFromServerId(targetPed)
    local target = GetPlayerPed(targetplayer)
    if not isSpectating then
        isSpectating = true
        SetEntityVisible(myPed, false) -- Set invisible
        SetEntityCollision(myPed, false, false) -- Set collision
        SetEntityInvincible(myPed, true) -- Set invincible
        NetworkSetEntityInvisibleToNetwork(myPed, true) -- Set invisibility
        lastSpectateCoord = GetEntityCoords(myPed) -- save my last coords
        NetworkSetInSpectatorMode(true, target) -- Enter Spectate Mode
    else
        isSpectating = false
        NetworkSetInSpectatorMode(false, target) -- Remove From Spectate Mode
        NetworkSetEntityInvisibleToNetwork(myPed, false) -- Set Visible
        SetEntityCollision(myPed, true, true) -- Set collision
        SetEntityCoords(myPed, lastSpectateCoord) -- Return Me To My Coords
        SetEntityVisible(myPed, true) -- Remove invisible
        SetEntityInvincible(myPed, false) -- Remove godmode
        lastSpectateCoord = nil -- Reset Last Saved Coords
    end
end)
