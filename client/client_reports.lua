local RSGCore = exports['rsg-core']:GetCoreObject()
local cooldown = false

lib.locale()

-- Menu principal des reports
RegisterNetEvent('rsg-adminmenu:client:reportsystem', function()
    lib.registerContext({
        id = 'reports_mainmenu',
        title = locale('cl_reports_menu'),
        menu = 'admin_mainmenu',
        onBack = function() end,
        options = {
            {
                title = locale('cl_reports_create'),
                description = locale('cl_reports_create_desc'),
                icon = 'fa-solid fa-plus',
                event = 'rsg-adminmenu:client:createreportmenu',
                arrow = true
            },
            {
                title = locale('cl_reports_view'),
                description = locale('cl_reports_view_desc'),
                icon = 'fa-solid fa-list',
                event = 'rsg-adminmenu:client:viewreports',
                arrow = true
            },
        }
    })
    lib.showContext('reports_mainmenu')
end)

-- Menu pour créer un report
RegisterNetEvent('rsg-adminmenu:client:createreportmenu', function()
    lib.registerContext({
        id = 'create_report_menu',
        title = locale('cl_reports_create_menu'),
        menu = 'reports_mainmenu',
        onBack = function() end,
        options = {
            {
                title = locale('cl_reports_player'),
                description = locale('cl_reports_player_desc'),
                icon = 'fa-solid fa-user-slash',
                event = 'rsg-adminmenu:client:createplayerreport',
                arrow = true
            },
            {
                title = locale('cl_reports_bug'),
                description = locale('cl_reports_bug_desc'), 
                icon = 'fa-solid fa-bug',
                event = 'rsg-adminmenu:client:createbugreport',
                arrow = true
            },
        }
    })
    lib.showContext('create_report_menu')
end)

-- Créer un report joueur
RegisterNetEvent('rsg-adminmenu:client:createplayerreport', function()
    if cooldown then
        lib.notify({title = locale('cl_reports_cooldown'), type = 'error'})
        return
    end
    
    local input = lib.inputDialog(locale('cl_reports_player_title'), {
        {type = 'number', label = locale('cl_reports_player_id'), required = true},
        {type = 'input', label = locale('cl_reports_reason'), required = true}
    })
    
    if not input then return end
    
    TriggerServerEvent('rsg-adminmenu:server:createplayerreport', input[1], input[2])
    cooldown = true
    SetTimeout(Config.Reports.Cooldown, function() cooldown = false end)
end)

-- Créer un report bug
RegisterNetEvent('rsg-adminmenu:client:createbugreport', function()
    if cooldown then
        lib.notify({title = locale('cl_reports_cooldown'), type = 'error'})
        return
    end
    
    local input = lib.inputDialog(locale('cl_reports_bug_title'), {
        {type = 'input', label = locale('cl_reports_bug_desc'), required = true},
        {type = 'input', label = locale('cl_reports_doing'), required = true},
        {type = 'input', label = locale('cl_reports_location'), required = false}
    })
    
    if not input then return end
    
    TriggerServerEvent('rsg-adminmenu:server:createbugreport', input[1], input[2], input[3])
    cooldown = true
    SetTimeout(Config.Reports.Cooldown, function() cooldown = false end)
end)

-- Voir les reports existants (ADMIN SEULEMENT)
RegisterNetEvent('rsg-adminmenu:client:viewreports', function()
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getreports', function(reports)
        if not reports or #reports == 0 then
            lib.notify({title = locale('cl_reports_no_reports'), type = 'inform'})
            return
        end
        
        local options = {}
        for k, v in pairs(reports) do
            options[#options + 1] = {
                title = string.format('[%s] %s vs %s', v.id, v.reporter_name, v.reported_name or 'BUG'),
                description = v.reason:sub(1, 50) .. '...',
                icon = v.type == 'player' and 'fa-solid fa-user-slash' or 'fa-solid fa-bug',
                event = 'rsg-adminmenu:client:handlereport',
                args = v,
                arrow = true
            }
        end
        
        lib.registerContext({
            id = 'view_reports_menu',
            title = locale('cl_reports_list'),
            menu = 'reports_mainmenu',
            onBack = function() end,
            options = options
        })
        lib.showContext('view_reports_menu')
    end)
end)

-- Menu de gestion d'un report spécifique (avec goto, spectate, bring)
RegisterNetEvent('rsg-adminmenu:client:handlereport', function(data)
    local options = {
        {
            title = locale('cl_reports_details'),
            description = data.reason,
            icon = 'fa-solid fa-info',
            readOnly = true
        }
    }
    
    -- Si c'est un report joueur, ajouter les actions admin
    if data.type == 'player' and data.reported_id then
        table.insert(options, {
            title = locale('cl_client_goto'),
            description = locale('cl_client_goto_desc'),
            icon = 'fa-solid fa-location-dot',
            serverEvent = 'rsg-adminmenu:server:gotoplayer',
            args = { id = data.reported_id },
            arrow = true
        })
        
        table.insert(options, {
            title = locale('cl_client_spectate'),
            description = locale('cl_client_spectate_desc'),
            icon = 'fa-solid fa-eye',
            serverEvent = 'rsg-adminmenu:server:spectateplayer',
            args = { id = data.reported_id },
            arrow = true
        })
        
        table.insert(options, {
            title = locale('cl_client_bring'),
            description = locale('cl_client_bring_desc'),
            icon = 'fa-solid fa-hand',
            serverEvent = 'rsg-adminmenu:server:bringplayer',
            args = { id = data.reported_id },
            arrow = true
        })
    end
    
    -- Bouton pour clore le report
    table.insert(options, {
        title = locale('cl_reports_close'),
        description = locale('cl_reports_close_desc'),
        icon = 'fa-solid fa-check',
        iconColor = 'green',
        event = 'rsg-adminmenu:client:closereport',
        args = { id = data.id },
        arrow = true
    })
    
    lib.registerContext({
        id = 'handle_report_menu',
        title = string.format('Report #%s', data.id),
        menu = 'view_reports_menu',
        onBack = function() end,
        options = options
    })
    lib.showContext('handle_report_menu')
end)

-- Clore un report
RegisterNetEvent('rsg-adminmenu:client:closereport', function(data)
    local input = lib.inputDialog(locale('cl_reports_close_title'), {
        {type = 'input', label = locale('cl_reports_close_reason'), required = true}
    })
    
    if not input then return end
    
    TriggerServerEvent('rsg-adminmenu:server:closereport', data.id, input[1])
end)
