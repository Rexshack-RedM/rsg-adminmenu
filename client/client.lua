local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-------------------------------
-- ACCES FOR KEY PGUP
-------------------------------
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustReleased(0, RSGCore.Shared.Keybinds['PGUP']) then
            ExecuteCommand("adminmenu")
        end
    end
end)

-------------------------------
-- main admin base menu
-------------------------------
RegisterNetEvent('rsg-adminmenu:client:openadminmenu', function()

    lib.registerContext({
        id = 'admin_mainmenu',
        title = locale('cl_client_0'),
        options = {
            {
                title = locale('cl_client_0'),
                description = locale('cl_client_1'),
                icon = 'fa-solid fa-user-secret',
                event = 'rsg-adminmenu:client:adminoptions',
                arrow = true
            },
            {
                title = locale('cl_report_admin_menu'),
                description = locale('cl_report_admin_menu_desc'),
                icon = 'fa-solid fa-ticket',
                event = 'rsg-adminmenu:client:adminreportsmenu',
                arrow = true
            },
            {
                title = locale('cl_client_2'),
                description = locale('cl_client_3'),
                icon = 'fa-solid fa-user',
                event = 'rsg-adminmenu:client:playersoptions',
                arrow = true
            },
            {
                title = locale('cl_client_88'),
                description = locale('cl_client_89'),
                icon = 'fa-solid fa-money-bill',
                event = 'rsg-adminmenu:client:playersfinances',
                arrow = true
            },
            {
                title = locale('cl_client_4'),
                description = locale('cl_client_5'),
                icon = 'fa-regular fa-face-grin-squint-tears',
                event = 'rsg-adminmenu:client:playerstroll',
                arrow = true
            },
            {
                title = locale('cl_client_6'),
                description = locale('cl_client_7'),
                icon = 'fa-solid fa-server',
                event = 'rsg-adminmenu:client:serveroptions',
                arrow = true
            },
            {
                title = locale('cl_client_8'),
                description = locale('cl_client_9'),
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

    local options = {
        {
            title = locale('cl_client_11'),
            description = locale('cl_client_12'),
            icon = 'fa-solid fa-up-down-left-right',
            event = 'RSGCore:Command:GoToMarker',
            arrow = true
        },
        {
            title = locale('cl_client_13'),
            description = locale('cl_client_14'),
            icon = 'fa-solid fa-heart-pulse',
            event = 'rsg-medic:client:playerRevive',
            arrow = true
        },
        {
            title = locale('cl_client_15'),
            description = locale('cl_client_16'),
            icon = 'fa-solid fa-ghost',
            onSelect = function()
                ExecuteCommand('txAdmin:menu:noClipToggle')
            end,
            arrow = true
        },
        {
            title = locale('cl_client_146'),
            description = locale('cl_client_147'),
            icon = 'fa-solid fa-id-card-clip',
            onSelect = function()
                ExecuteCommand('txAdmin:menu:togglePlayerIDs')
            end,
            arrow = true
        },
        {
            title = locale('cl_client_17'),
            description = locale('cl_client_18'),
            icon = 'fa-solid fa-book-bible',
            event = 'rsg-adminmenu:client:godmode',
            arrow = true
        },
    }
    
    if Config.EnablePlayerBlips then
        table.insert(options, {
            title = locale('cl_client_154'),
            description = locale('cl_client_155'),
            icon = 'fa-solid fa-map-location-dot',
            event = 'rsg-adminmenu:client:toggleplayerblips',
            arrow = true
        })
    end
    
    lib.registerContext({
        id = 'admin_optionsmenu',
        title = locale('cl_client_10'),
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = options
    })
    
    lib.showContext('admin_optionsmenu')

end)

----------------------------------------
-- player options
----------------------------------------
RegisterNetEvent('rsg-adminmenu:client:playersoptions', function()
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getplayers', function(players)
        local options = {}
        for k, v in pairs(players) do
            options[#options + 1] = {
                title = locale('cl_client_19') .. ' ' ..v.id..' | '..v.name,
                icon = 'fa-solid fa-circle-user',
                event = 'rsg-adminmenu:client:playermenu',
                args = { name = v.name, player = v.id },
                arrow = true,
            }
        end
        lib.registerContext({
            id = 'players_optionssmenu',
            title = locale('cl_client_21'),
            menu = 'admin_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('players_optionssmenu')
    end)
end)

--------------------------------------
-- player menu
--------------------------------------
RegisterNetEvent('rsg-adminmenu:client:playermenu', function(data)

    lib.registerContext({
        id = 'player_menu',
        title = data.name,
        menu = 'players_optionssmenu',
        onBack = function() end,
        options = {
            {
                title = locale('cl_client_137'),
                description = locale('cl_client_138'),
                icon = 'fa-solid fa-briefcase-medical',
                event = 'rsg-adminmenu:server:playerinfo',
                args = { id = data.player },
                arrow = true
            },
            {
                title = locale('cl_client_22'),
                description = locale('cl_client_23'),
                icon = 'fa-solid fa-briefcase-medical',
                serverEvent = 'rsg-adminmenu:server:playerrevive',
                args = { id = data.player },
                arrow = true
            },
            {
                title = locale('cl_client_130'),
                description = locale('cl_client_131'),
                icon = 'fa-solid fa-gift',
                event = 'rsg-adminmenu:client:giveitem',
                args = { id = data.player },
                arrow = true
            },
            {
                title = locale('cl_client_24'),
                description = locale('cl_client_25'),
                icon = 'fa-solid fa-box',
                serverEvent = 'rsg-adminmenu:server:openinventory',
                args = { id = data.player },
                arrow = true
            },
            {
                title = locale('cl_client_26'),
                description = locale('cl_client_27'),
                icon = 'fa-solid fa-socks',
                event = 'rsg-adminmenu:client:kickplayer',
                args = { id = data.player, name = data.name },
                arrow = true
            },
            {
                title = locale('cl_client_28'),
                description = locale('cl_client_29'),
                icon = 'fa-solid fa-ban',
                event = 'rsg-adminmenu:client:banplayer',
                args = { id = data.player, name = data.name },
                arrow = true
            },
            {
                title = locale('cl_client_30'),
                description = locale('cl_client_31'),
                icon = 'fa-solid fa-location-dot',
                serverEvent = 'rsg-adminmenu:server:gotoplayer',
                args = { id = data.player },
                arrow = true
            },
            {
                title = locale('cl_client_32'),
                description = locale('cl_client_33'),
                icon = 'fa-solid fa-hand',
                serverEvent = 'rsg-adminmenu:server:bringplayer',
                args = { id = data.player },
                arrow = true
            },
            {
                title = locale('cl_client_34'),
                description = locale('cl_client_35'),
                icon = 'fa-solid fa-snowflake',
                serverEvent = 'rsg-adminmenu:server:freezeplayer',
                args = { id = data.player, name = data.name },
                arrow = true
            },
            {
                title = locale('cl_client_36'),
                description = locale('cl_client_37'),
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
        title = locale('cl_client_38'),
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = {
            {
                title = locale('cl_client_39'),
                description = locale('cl_client_40'),
                icon = 'fa-solid fa-cloud-sun',
                event = 'weathersync:openAdminUi',
                arrow = true
            },
        }
    })
    lib.showContext('server_optionssmenu')

end)

-------------------------------------------------------------------
-- toggle player blips
-------------------------------------------------------------------
local playerBlipsEnabled = false
local playerBlips = {}
local blipUpdateThread = nil

RegisterNetEvent('rsg-adminmenu:client:toggleplayerblips', function()
    local playerId = PlayerId()
    local serverId = GetPlayerServerId(playerId)
    local playerName = GetPlayerName(playerId)

    playerBlipsEnabled = not playerBlipsEnabled

    if playerBlipsEnabled then
        lib.notify({ title = locale('cl_client_156'), description = locale('cl_client_157'), type = 'inform' })
        TriggerServerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('cl_adminmenu'), 'red', playerName .. ' (ID: ' .. serverId .. ') ' .. locale('cl_adminmenu_e'))

        if not blipUpdateThread then
            blipUpdateThread = CreateThread(function()
                while playerBlipsEnabled do
                    Wait(1000)
                    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getplayers', function(players)
                        for _, player in pairs(players) do
                            if player.id ~= playerId then
                                if not playerBlips[player.id] then
                                    local blip = BlipAddForCoords(1664425300, player.coords.x, player.coords.y, player.coords.z)
                                    SetBlipSprite(blip, GetHashKey('blip_ambient_companion'))
                                    SetBlipScale(blip, 0.6)
                                    local steamName = GetPlayerName(GetPlayerFromServerId(player.id))
                                    SetBlipName(blip, 'ID: ' .. player.id .. ' ' .. steamName)
                                    playerBlips[player.id] = blip
                                else
                                    SetBlipCoords(playerBlips[player.id], player.coords.x, player.coords.y, player.coords.z)
                                end
                            end
                        end

                        for blipId, blip in pairs(playerBlips) do
                            local found = false
                            for _, player in pairs(players) do
                                if player.id == blipId then
                                    found = true
                                    break
                                end
                            end
                            if not found then
                                RemoveBlip(blip)
                                playerBlips[blipId] = nil
                            end
                        end
                    end)
                end
                blipUpdateThread = nil
            end)
        end
    else
        lib.notify({ title = locale('cl_client_158'), description = locale('cl_client_159'), type = 'inform' })
        TriggerServerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('cl_adminmenu'), 'red', playerName .. ' (ID: ' .. serverId .. ') ' .. locale('cl_adminmenu_f'))

        for _, blip in pairs(playerBlips) do
            RemoveBlip(blip)
        end
        playerBlips = {}
    end
end)

-------------------------------------------------------------------
-- go invisible
-------------------------------------------------------------------
local invisible = false
RegisterNetEvent('rsg-adminmenu:client:goinvisible', function()
    local playerId = PlayerId()
    local serverId = GetPlayerServerId(playerId)
    local playerName = GetPlayerName(playerId)

    if invisible then
        -- Invisibility disabled
        SetEntityVisible(cache.ped, true)
        invisible = false
        lib.notify({ title = locale('cl_client_42'), description = locale('cl_client_43'), type = 'inform' })
        TriggerServerEvent(
            'rsg-log:server:CreateLog',
            'adminmenu',
            locale('cl_adminmenu'),
            'red',
            playerName .. ' (ID: ' .. serverId .. ') ' .. locale('cl_adminmenu_d') -- disabled invisibility
        )
    else
        -- Invisibility enabled
        SetEntityVisible(cache.ped, false)
        invisible = true
        lib.notify({ title = locale('cl_client_44'), description = locale('cl_client_45'), type = 'inform' })
        TriggerServerEvent(
            'rsg-log:server:CreateLog',
            'adminmenu',
            locale('cl_adminmenu'),
            'red',
            playerName .. ' (ID: ' .. serverId .. ') ' .. locale('cl_adminmenu_a') -- enabled invisibility
        )
    end
end)

-------------------------------------------------------------------
-- god mode
-------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:godmode', function()
    godmode = not godmode

    local playerId = PlayerId()
    local serverId = GetPlayerServerId(playerId)
    local playerName = GetPlayerName(playerId)

    if godmode then
        -- Godmode enabled
        lib.notify({ title = locale('cl_client_46'), description = locale('cl_client_47'), type = 'inform' })
        TriggerServerEvent(
            'rsg-log:server:CreateLog',
            'adminmenu',
            locale('cl_adminmenu'),
            'red',
            playerName .. ' (ID: ' .. serverId .. ') ' .. locale('cl_adminmenu_b') -- enabled godmode
        )
        while godmode do
            Wait(0)
            SetPlayerInvincible(cache.ped, true)
        end
    else
        -- Godmode disabled
        SetPlayerInvincible(cache.ped, false)
        lib.notify({ title = locale('cl_client_48'), description = locale('cl_client_49'), type = 'inform' })
        TriggerServerEvent(
            'rsg-log:server:CreateLog',
            'adminmenu',
            locale('cl_adminmenu'),
            'red',
            playerName .. ' (ID: ' .. serverId .. ') ' .. locale('cl_adminmenu_c') -- disabled godmode
        )
    end
end)


------------------------
-- kick player reason
------------------------
RegisterNetEvent('rsg-adminmenu:client:kickplayer', function(data)
    local input = lib.inputDialog(locale('cl_client_50') .. ': '..data.name, {
        {
            label = locale('cl_client_51'),
            type = 'input',
            required = true,
        },
    })
    if not input then return end

    TriggerServerEvent('rsg-adminmenu:server:kickplayer', data.id, input[1])

end)

----------------------
-- ban player reason
----------------------
RegisterNetEvent('rsg-adminmenu:client:banplayer', function(data)
    local input = lib.inputDialog(locale('cl_client_52').. ': '..data.name, {
        {
            label = locale('cl_client_53'),
            type = 'select',
                options = {
                    { value = "permanent", label = locale('cl_client_53_a') },
                    { value = "temporary", label = locale('cl_client_53_b') },
                },
            required = true,
        },
        {
            label = locale('cl_client_54'),
            type = 'select',
                options = {
                    { value = '3600', label = locale('cl_client_55') },
                    { value = '21600', label = locale('cl_client_56') },
                    { value = '43200', label = locale('cl_client_57') },
                    { value = '86400', label = locale('cl_client_58') },
                    { value = '259200', label = locale('cl_client_59') },
                    { value = '604800', label = locale('cl_client_60') },
                    { value = '2678400', label = locale('cl_client_61') },
                    { value = '8035200', label = locale('cl_client_62') },
                    { value = '16070400', label = locale('cl_client_63') },
                    { value = '32140800', label = locale('cl_client_64') },
                    { value = '99999999999', label = locale('cl_client_65') },
                },
            required = true,
        },
        {
            label = locale('cl_client_51'),
            type = 'input',
            required = true,
        }
    })

    if not input then return end

    -- permanent ban
    if input[1] == 'permanent' then
        TriggerServerEvent('rsg-adminmenu:server:banplayer', data.id, '99999999999', input[3])
        lib.notify({ title = locale('cl_client_66'), description = data.name..locale('cl_client_67'), type = 'inform' })
    end
    -- temporary ban
    if input[1] == 'temporary' then
        TriggerServerEvent('rsg-adminmenu:server:banplayer', data.id, input[2], input[3])
        lib.notify({ title = locale('cl_client_66'), description = data.name..locale('cl_client_68'), type = 'inform' })
    end
end)

--------------------
-- spectate player
--------------------

local lastSpectateCoord = nil
local isSpectating = false

RegisterNetEvent('rsg-adminmenu:client:spectateplayer', function(targetPed)
    local targetplayer = GetPlayerFromServerId(targetPed)
    local target = GetPlayerPed(targetplayer)
    if not isSpectating then
        isSpectating = true
        SetEntityVisible(cache.ped, false) -- Set invisible
        SetEntityCollision(cache.ped, false, false) -- Set collision
        SetEntityInvincible(cache.ped, true) -- Set invincible
        NetworkSetEntityInvisibleToNetwork(cache.ped, true) -- Set invisibility
        lastSpectateCoord = GetEntityCoords(cache.ped) -- save my last coords
        NetworkSetInSpectatorMode(true, target) -- Enter Spectate Mode
    else
        isSpectating = false
        NetworkSetInSpectatorMode(false, target) -- Remove From Spectate Mode
        NetworkSetEntityInvisibleToNetwork(cache.ped, false) -- Set Visible
        SetEntityCollision(cache.ped, true, true) -- Set collision
        SetEntityCoords(cache.ped, lastSpectateCoord) -- Return Me To My Coords
        SetEntityVisible(cache.ped, true) -- Remove invisible
        SetEntityInvincible(cache.ped, false) -- Remove godmode
        lastSpectateCoord = nil -- Reset Last Saved Coords
    end
end)

-----------------------
-- sort table function
-----------------------
local function compareNames(a, b)
    return a.value < b.value
end

---------------------
-- give item
---------------------
RegisterNetEvent('rsg-adminmenu:client:giveitem', function(data)
    local items = RSGCore.Shared.Items

    local searchInput = lib.inputDialog('Search and Give Item', {
        {
            type = 'input',
            label = 'Search Item',
            placeholder = 'e.g. revolver, bandage...',
            required = true
        }
    })

    if not searchInput then return end
    local keyword = searchInput[1]:lower()

    -- 2. Filter matching items
    local options = {}
    for _, item in pairs(items) do
        local label = item.label or item.name
        if label:lower():find(keyword, 1, true) then
            options[#options+1] = {
                value = item.name,
                label = label
            }
        end
    end

    if #options == 0 then
        return lib.notify({ type = 'error', description = 'No item found for "'..keyword..'"' })
    end

    local result = lib.inputDialog('Select and Confirm', {
        {
            type = 'select',
            label = 'Item to Give',
            options = options,
            required = true,
            search = true
        },
        {
            type = 'number',
            label = 'Quantity',
            required = true
        }
    })

    if not result then return end

    local selectedItem = result[1]
    local quantity = tonumber(result[2])

    if not selectedItem or not quantity or quantity <= 0 then
        return lib.notify({ type = 'error', description = 'Invalid input.' })
    end

    TriggerServerEvent('rsg-adminmenu:server:giveitem', data.id, selectedItem, quantity)
end)

-------------------------
-- player info
-------------------------
RegisterNetEvent('rsg-adminmenu:server:playerinfo', function(player)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getplayerinfo', function(data)
        lib.registerContext(
            {
                id = 'adminplayer_info',
                title = locale('cl_client_139'),
                description = '',
                menu = 'players_optionssmenu',
                onBack = function() end,
                position = 'top-right',
                options = {
                    {
                        title = locale('cl_client_140')..': '..data.firstname..' '..data.lastname,
                        icon = 'user',
                    },
                    {
                        title = locale('cl_client_141')..': '..data.job,
                        icon = 'user',
                    },
                    {
                        title = locale('cl_client_142')..': '..tostring(data.grade),
                        icon = 'user',
                    },
                    {
                        title = locale('cl_client_143')..': '..tostring(data.cash),
                        icon = 'fa-solid fa-money-bill',
                    },
                    {
                        title = locale('cl_client_144')..': '..tostring(data.bloodmoney),
                        icon = 'fa-solid fa-money-bill',
                    },
                    {
                        title = locale('cl_client_153')..': '..tostring(data.bank),
                        icon = 'fa-solid fa-building-columns',
                    },
                    {
                        title = locale('cl_client_148')..': '..tostring(data.valbank),
                        icon = 'fa-solid fa-building-columns',
                    },
                    {
                        title = locale('cl_client_149')..': '..tostring(data.rhobank),
                        icon = 'fa-solid fa-building-columns',
                    },
                    {
                        title = locale('cl_client_150')..': '..tostring(data.blkbank),
                        icon = 'fa-solid fa-building-columns',
                    },
                    {
                        title = locale('cl_client_151')..': '..tostring(data.armbank),
                        icon = 'fa-solid fa-building-columns',
                    },
                    {
                        title = 'CitizenID : '..data.citizenid,
                        icon = 'fa-solid fa-id-card',
                    },
                    {
                        title = 'ServerID : '..data.serverid,
                        icon = 'fa-solid fa-server',
                    },
                }
            }
        )
        lib.showContext('adminplayer_info')
    end, player)
end)
