local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- troll players menu
RegisterNetEvent('rsg-adminmenu:client:playerstroll', function()
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getplayers', function(players)
        local options = {}
        for k, v in pairs(players) do
            options[#options + 1] = {
                title = locale('cl_troll_19') .. ': ' .. v.id..' | '..v.name,
                icon = 'fa-solid fa-circle-user',
                event = 'rsg-adminmenu:client:trolloptions',
                args = { name = v.name, player = v.id },
                arrow = true,
            }
        end
        lib.registerContext({
            id = 'troll_menu',
            title = locale('cl_troll_84'),
            menu = 'admin_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('troll_menu')
    end)
end)

-- troll options menu
RegisterNetEvent('rsg-adminmenu:client:trolloptions', function(data)

    lib.registerContext({
        id = 'troll_optionsmenu',
        title = locale('cl_troll_85'),
        menu = 'troll_menu',
        onBack = function() end,
        options = {
            {
                title = locale('cl_troll_86'),
                description = locale('cl_troll_87'),
                icon = 'fa-solid fa-paw',
                serverEvent = 'rsg-adminmenu:server:wildattack',
                args = { id = data.player },
                arrow = true
            },
            {
                title = locale('cl_troll_128'),
                description = locale('cl_troll_129'),
                icon = 'fa-solid fa-fire',
                serverEvent = 'rsg-adminmenu:server:playerfire',
                args = { id = data.player },
                arrow = true
            },
        }
    })
    lib.showContext('troll_optionsmenu')

end)

-------------------------------------------------------------------
-- wild attack troll action
-------------------------------------------------------------------
local attackAnimals = {
    joaat("a_c_wolf_small"),
    joaat("a_c_bearblack_01"),
    joaat("a_c_dogrufus_01")
}

local animalGroupHash = joaat("Animal")
local playerGroupHash = joaat("PLAYER")

RegisterNetEvent('rsg-adminmenu:client:wildattack', function(player)
    local targetplayer = GetPlayerFromServerId(player)
    local playerPed = GetPlayerPed(targetplayer)
    local animalHash = attackAnimals[math.random(#attackAnimals)]
    local coordsBehindPlayer = GetOffsetFromEntityInWorldCoords(playerPed, 100, -15.0, 0)
    local playerHeading = GetEntityHeading(playerPed)
    local belowGround, groundZ, vec3OnFloor = GetGroundZAndNormalFor_3dCoord(coordsBehindPlayer.x, coordsBehindPlayer.y, coordsBehindPlayer.z)

    -- request model
    RequestModel(animalHash)
    while not HasModelLoaded(animalHash) do
        Wait(15)
    end

    -- creating animal
    animalPed = CreatePed(animalHash, coordsBehindPlayer.x, coordsBehindPlayer.y, groundZ, playerHeading, true, false)
    EquipMetaPedOutfitPreset(animalPed, 1, 0)

    -- setting player as enemy
    SetPedFleeAttributes(animalPed, 0, 0)
    SetPedRelationshipGroupHash(animalPed, animalGroupHash)
    TaskSetBlockingOfNonTemporaryEvents(animalPed, true)
    TaskCombatHatedTargetsAroundPed(animalPed, 30.0, 0)
    ClearPedTasks(animalPed)
    TaskPutPedDirectlyIntoMelee(animalPed, playerPed, 0.0, -1.0, 0.0, 0)
    SetRelationshipBetweenGroups(5, animalGroupHash, playerGroupHash)
    SetRelationshipBetweenGroups(5, playerGroupHash, animalGroupHash)
    SetModelAsNoLongerNeeded(animalHash)

end)

-------------------------------------------------------------------
-- set player on fire troll action
-------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:playerfire', function(player)
    local targetplayer = GetPlayerFromServerId(player)
    local playerPed = GetPlayerPed(targetplayer)
    StartEntityFire(playerPed)
end)