local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local reportCooldown = false

-----------------------------------------------------------------------
-- Main report menu (for players)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:openreportmenu', function()
    lib.registerContext({
        id = 'player_report_menu',
        title = locale('cl_report_menu_title'),
        options = {
            {
                title = locale('cl_report_create'),
                description = locale('cl_report_create_desc'),
                icon = 'fa-solid fa-plus',
                event = 'rsg-adminmenu:client:createreport',
                arrow = true
            },
            {
                title = locale('cl_report_myreports'),
                description = locale('cl_report_myreports_desc'),
                icon = 'fa-solid fa-list',
                event = 'rsg-adminmenu:client:viewmyreports',
                arrow = true
            },
        }
    })
    lib.showContext('player_report_menu')
end)

-----------------------------------------------------------------------
-- Create a new report
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:createreport', function()
    if reportCooldown then
        lib.notify({ 
            title = locale('cl_report_cooldown_title'), 
            description = locale('cl_report_cooldown_desc'), 
            type = 'error' 
        })
        return
    end

    -- Step 1: Select the report type
    local typeInput = lib.inputDialog(locale('cl_report_select_type'), {
        {
            label = locale('cl_report_type'),
            type = 'select',
            options = {
                { value = 'bug', label = locale('cl_report_type_bug') },
                { value = 'player', label = locale('cl_report_type_player') },
                { value = 'question', label = locale('cl_report_type_question') }
            },
            required = true,
        }
    })

    if not typeInput then return end
    
    local selectedType = typeInput[1]

    -- Step 2: Build fields based on the selected type
    local fields = {
        {
            label = locale('cl_report_title_input'),
            type = 'input',
            required = true,
            min = 5,
            max = 100,
        },
        {
            label = locale('cl_report_description'),
            type = 'textarea',
            required = true,
            min = 10,
            max = 500,
        }
    }

    -- Add player ID field only for player reports
    if selectedType == 'player' then
        fields[#fields + 1] = {
            label = locale('cl_report_player_id'),
            description = locale('cl_report_player_id_desc'),
            type = 'number',
            required = false,
        }
    end

    -- Add image URL field only for bug and player reports (not for questions)
    if selectedType ~= 'question' then
        fields[#fields + 1] = {
            label = locale('cl_report_image_url'),
            description = locale('cl_report_image_url_desc'),
            type = 'input',
            required = false,
        }
    end

    local input = lib.inputDialog(locale('cl_report_create_title'), fields)

    if not input then return end

    -- Build data based on the type
    local reportData = {
        reportType = selectedType,
        title = input[1],
        description = input[2],
        reportedPlayerId = nil,
        imageUrl = nil,
    }

    -- Map fields according to type
    if selectedType == 'player' then
        reportData.reportedPlayerId = input[3]
        reportData.imageUrl = input[4]
    elseif selectedType == 'bug' then
        reportData.imageUrl = input[3]
    end

    TriggerServerEvent('rsg-adminmenu:server:createreport', reportData)
    
    -- Cooldown
    reportCooldown = true
    SetTimeout(Config.Reports.Cooldown * 1000, function()
        reportCooldown = false
    end)
end)

-----------------------------------------------------------------------
-- View my reports
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:viewmyreports', function()
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getmyreports', function(reports)
        if not reports or #reports == 0 then
            lib.notify({ 
                title = locale('cl_report_no_reports'), 
                description = locale('cl_report_no_reports_desc'), 
                type = 'inform' 
            })
            return
        end

        local options = {}
        for _, report in ipairs(reports) do
            local statusColor = '🔵'
            if report.status == 'claimed' then statusColor = '🟡'
            elseif report.status == 'resolved' then statusColor = '🟢'
            elseif report.status == 'closed' then statusColor = '⚫' end

            local statusText = locale('cl_report_status_' .. report.status)
            local typeText = locale('cl_report_type_' .. report.report_type)

            options[#options + 1] = {
                title = statusColor .. ' #' .. report.id .. ' - ' .. report.title,
                description = locale('cl_report_list_desc', typeText, statusText),
                icon = 'fa-solid fa-file-lines',
                event = 'rsg-adminmenu:client:viewreportdetails',
                args = { reportId = report.id },
                arrow = true,
            }
        end

        lib.registerContext({
            id = 'my_reports_list',
            title = locale('cl_report_myreports'),
            menu = 'player_report_menu',
            onBack = function() end,
            options = options
        })
        lib.showContext('my_reports_list')
    end)
end)

-----------------------------------------------------------------------
-- View report details (player)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:viewreportdetails', function(data)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getreportdetails', function(report, messages)
        if not report then
            lib.notify({ title = locale('cl_report_error'), description = locale('cl_report_not_found'), type = 'error' })
            return
        end

        local statusText = locale('cl_report_status_' .. report.status)
        local typeText = locale('cl_report_type_' .. report.report_type)

        local options = {
            {
                title = locale('cl_report_info'),
                description = locale('cl_report_info_desc', report.id, typeText, statusText),
                icon = 'fa-solid fa-info-circle',
                disabled = true,
            },
            {
                title = locale('cl_report_description_title'),
                description = report.description,
                icon = 'fa-solid fa-align-left',
                disabled = true,
            },
        }

        -- Show image if available
        if report.image_url and report.image_url ~= '' then
            options[#options + 1] = {
                title = locale('cl_report_view_image'),
                description = locale('cl_report_view_image_desc'),
                icon = 'fa-solid fa-image',
                onSelect = function()
                    lib.setClipboard(report.image_url)
                    lib.notify({ 
                        title = locale('cl_report_url_copied'), 
                        description = report.image_url, 
                        type = 'success' 
                    })
                end,
            }
        end

        -- Message history
        if messages and #messages > 0 then
            options[#options + 1] = {
                title = locale('cl_report_messages_history'),
                description = locale('cl_report_messages_count', #messages),
                icon = 'fa-solid fa-comments',
                event = 'rsg-adminmenu:client:viewreportmessages',
                args = { reportId = report.id, messages = messages },
                arrow = true,
            }
        end

        -- Reply to the report
        if report.status ~= 'closed' then
            options[#options + 1] = {
                title = locale('cl_report_reply'),
                description = locale('cl_report_reply_desc'),
                icon = 'fa-solid fa-reply',
                event = 'rsg-adminmenu:client:replyreport',
                args = { reportId = report.id },
                arrow = true,
            }
        end

        lib.registerContext({
            id = 'report_details',
            title = '#' .. report.id .. ' - ' .. report.title,
            menu = 'my_reports_list',
            onBack = function() end,
            options = options
        })
        lib.showContext('report_details')
    end, data.reportId)
end)

-----------------------------------------------------------------------
-- Reply to a report (player)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:replyreport', function(data)
    local input = lib.inputDialog(locale('cl_report_reply_title'), {
        {
            label = locale('cl_report_message'),
            type = 'textarea',
            required = true,
            min = 5,
            max = 500,
        },
    })

    if not input then return end

    TriggerServerEvent('rsg-adminmenu:server:replyreport', data.reportId, input[1], 'player')
end)

-----------------------------------------------------------------------
-- View message history
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:viewreportmessages', function(data)
    local options = {}
    
    for _, msg in ipairs(data.messages) do
        local icon = msg.sender_type == 'admin' and 'fa-solid fa-user-shield' or 'fa-solid fa-user'
        local senderTypeText = msg.sender_type == 'admin' and locale('cl_report_sender_admin') or locale('cl_report_sender_player')
        
        options[#options + 1] = {
            title = msg.sender_name .. ' (' .. senderTypeText .. ')',
            description = msg.message .. '\n\n' .. msg.created_at_text,
            icon = icon,
            disabled = true,
        }
    end

    lib.registerContext({
        id = 'report_messages',
        title = locale('cl_report_messages_history'),
        menu = 'report_details',
        onBack = function() end,
        options = options
    })
    lib.showContext('report_messages')
end)

-----------------------------------------------------------------------
-- ADMIN SECTION - Admin report menu
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:adminreportsmenu', function()
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getallreports', function(reports)
        if not reports or #reports == 0 then
            lib.notify({ 
                title = locale('cl_report_admin_no_reports'), 
                description = locale('cl_report_admin_no_reports_desc'), 
                type = 'inform' 
            })
            return
        end

        local options = {}
        for _, report in ipairs(reports) do
            local statusColor = '🔵'
            if report.status == 'claimed' then statusColor = '🟡'
            elseif report.status == 'resolved' then statusColor = '🟢'
            elseif report.status == 'closed' then statusColor = '⚫' end

            local typeText = locale('cl_report_type_' .. report.report_type)
            local assignedText = report.assigned_admin_name and locale('cl_report_assigned_to', report.assigned_admin_name) or ''
            
            options[#options + 1] = {
                title = statusColor .. ' #' .. report.id .. ' - ' .. report.title,
                description = locale('cl_report_admin_list_desc', typeText, report.reporter_name) .. assignedText,
                icon = 'fa-solid fa-file-lines',
                event = 'rsg-adminmenu:client:adminviewreport',
                args = { reportId = report.id },
                arrow = true,
            }
        end

        lib.registerContext({
            id = 'admin_reports_list',
            title = locale('cl_report_admin_menu_title'),
            menu = 'admin_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('admin_reports_list')
    end)
end)

-----------------------------------------------------------------------
-- Admin - View report details
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:adminviewreport', function(data)
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getreportdetails', function(report, messages, nearbyPlayers)
        if not report then
            lib.notify({ title = locale('cl_report_error'), description = locale('cl_report_not_found'), type = 'error' })
            return
        end

        local statusText = locale('cl_report_status_' .. report.status)
        local typeText = locale('cl_report_type_' .. report.report_type)

        local options = {
            {
                title = locale('cl_report_admin_info'),
                description = locale('cl_report_admin_info_desc', report.id, typeText, statusText, report.reporter_name),
                icon = 'fa-solid fa-info-circle',
                disabled = true,
            },
            {
                title = locale('cl_report_description_title'),
                description = report.description,
                icon = 'fa-solid fa-align-left',
                disabled = true,
            },
        }

        -- Admin actions on the report
        options[#options + 1] = {
            title = locale('cl_report_admin_actions'),
            description = locale('cl_report_admin_actions_desc'),
            icon = 'fa-solid fa-tasks',
            event = 'rsg-adminmenu:client:reportactions',
            args = { reportId = report.id, status = report.status },
            arrow = true,
        }

        -- Actions on the reporter
        options[#options + 1] = {
            title = locale('cl_report_reporter_actions'),
            description = locale('cl_report_player_info', report.reporter_name, report.reporter_id),
            icon = 'fa-solid fa-user',
            event = 'rsg-adminmenu:client:reportplayeractions',
            args = { playerId = report.reporter_id, playerName = report.reporter_name },
            arrow = true,
        }

        -- Actions on the reported player
        if report.reported_player_id and report.reported_player_name then
            options[#options + 1] = {
                title = locale('cl_report_reported_actions'),
                description = locale('cl_report_player_info', report.reported_player_name, report.reported_player_id),
                icon = 'fa-solid fa-user-injured',
                event = 'rsg-adminmenu:client:reportplayeractions',
                args = { playerId = report.reported_player_id, playerName = report.reported_player_name },
                arrow = true,
            }
        end

        -- Nearby players
        if nearbyPlayers and #nearbyPlayers > 0 then
            options[#options + 1] = {
                title = locale('cl_report_nearby_players'),
                description = locale('cl_report_nearby_count', #nearbyPlayers),
                icon = 'fa-solid fa-users',
                event = 'rsg-adminmenu:client:viewnearbyplayers',
                args = { players = nearbyPlayers },
                arrow = true,
            }
        end

        -- Image URL
        if report.image_url and report.image_url ~= '' then
            options[#options + 1] = {
                title = locale('cl_report_view_image'),
                description = locale('cl_report_view_image_desc'),
                icon = 'fa-solid fa-image',
                onSelect = function()
                    lib.setClipboard(report.image_url)
                    lib.notify({ 
                        title = locale('cl_report_url_copied'), 
                        description = report.image_url, 
                        type = 'success' 
                    })
                end,
            }
        end

        -- Messages
        if messages and #messages > 0 then
            options[#options + 1] = {
                title = locale('cl_report_messages_history'),
                description = locale('cl_report_messages_count', #messages),
                icon = 'fa-solid fa-comments',
                event = 'rsg-adminmenu:client:viewreportmessages',
                args = { reportId = report.id, messages = messages },
                arrow = true,
            }
        end

        -- Reply
        options[#options + 1] = {
            title = locale('cl_report_admin_reply'),
            description = locale('cl_report_admin_reply_desc'),
            icon = 'fa-solid fa-reply',
            event = 'rsg-adminmenu:client:adminreplyreport',
            args = { reportId = report.id },
            arrow = true,
        }

        lib.registerContext({
            id = 'admin_report_details',
            title = '#' .. report.id .. ' - ' .. report.title,
            menu = 'admin_reports_list',
            onBack = function() end,
            options = options
        })
        lib.showContext('admin_report_details')
    end, data.reportId)
end)

-----------------------------------------------------------------------
-- Admin - Report actions
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:reportactions', function(data)
    local options = {}

    if data.status ~= 'closed' then
        options[#options + 1] = {
            title = locale('cl_report_claim'),
            description = locale('cl_report_claim_desc'),
            icon = 'fa-solid fa-hand',
            serverEvent = 'rsg-adminmenu:server:claimreport',
            args = { reportId = data.reportId },
        }
    end

    if data.status == 'claimed' then
        options[#options + 1] = {
            title = locale('cl_report_release'),
            description = locale('cl_report_release_desc'),
            icon = 'fa-solid fa-unlock',
            serverEvent = 'rsg-adminmenu:server:releasereport',
            args = { reportId = data.reportId },
        }
    end

    if data.status ~= 'resolved' and data.status ~= 'closed' then
        options[#options + 1] = {
            title = locale('cl_report_resolve'),
            description = locale('cl_report_resolve_desc'),
            icon = 'fa-solid fa-check',
            serverEvent = 'rsg-adminmenu:server:resolvereport',
            args = { reportId = data.reportId },
        }
    end

    options[#options + 1] = {
        title = locale('cl_report_delete'),
        description = locale('cl_report_delete_desc'),
        icon = 'fa-solid fa-trash',
        event = 'rsg-adminmenu:client:deletereport',
        args = { reportId = data.reportId },
    }

    lib.registerContext({
        id = 'report_actions',
        title = locale('cl_report_admin_actions'),
        menu = 'admin_report_details',
        onBack = function() end,
        options = options
    })
    lib.showContext('report_actions')
end)

-----------------------------------------------------------------------
-- Admin - Delete a report
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:deletereport', function(data)
    local input = lib.inputDialog(locale('cl_report_delete_title'), {
        {
            label = locale('cl_report_delete_reason'),
            type = 'textarea',
            required = true,
            min = 5,
            max = 255,
        },
    })

    if not input then return end

    TriggerServerEvent('rsg-adminmenu:server:deletereport', data.reportId, input[1])
end)

-----------------------------------------------------------------------
-- Admin - Reply to a report
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:adminreplyreport', function(data)
    local input = lib.inputDialog(locale('cl_report_admin_reply_title'), {
        {
            label = locale('cl_report_message'),
            type = 'textarea',
            required = true,
            min = 5,
            max = 500,
        },
    })

    if not input then return end

    TriggerServerEvent('rsg-adminmenu:server:replyreport', data.reportId, input[1], 'admin')
end)

-----------------------------------------------------------------------
-- Admin - Player actions from report
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:reportplayeractions', function(data)
    -- Retrieve player name from the server to ensure they're online
    RSGCore.Functions.TriggerCallback('rsg-adminmenu:server:getplayers', function(players)
        local playerFound = false
        local playerName = data.playerName
        
        -- Check if the player is still online
        for _, player in pairs(players) do
            if player.id == data.playerId then
                playerFound = true
                playerName = player.name
                break
            end
        end
        
        if not playerFound then
            lib.notify({ 
                title = locale('cl_report_error'), 
                description = locale('cl_report_player_offline'), 
                type = 'error' 
            })
            return
        end
        
        -- Redirect to existing player menu from admin menu
        TriggerEvent('rsg-adminmenu:client:playermenu', {
            name = playerName,
            player = data.playerId
        })
    end)
end)

-----------------------------------------------------------------------
-- Admin - View nearby players
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:viewnearbyplayers', function(data)
    local options = {}
    
    for _, player in ipairs(data.players) do
        options[#options + 1] = {
            title = locale('cl_report_nearby_player_title', player.player_name, player.player_id),
            description = locale('cl_report_nearby_player_desc', string.format("%.2f", player.distance), player.player_license),
            icon = 'fa-solid fa-user',
            event = 'rsg-adminmenu:client:reportplayeractions',
            args = { playerId = player.player_id, playerName = player.player_name },
            arrow = true,
        }
    end

    lib.registerContext({
        id = 'nearby_players_list',
        title = locale('cl_report_nearby_players'),
        menu = 'admin_report_details',
        onBack = function() end,
        options = options
    })
    lib.showContext('nearby_players_list')
end)

-----------------------------------------------------------------------
-- Notification of new report (for admins)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:newreportnotification', function(reportData)
    local typeText = locale('cl_report_type_' .. reportData.report_type)
    lib.notify({ 
        title = locale('cl_report_new_notification'), 
        description = locale('cl_report_new_desc', reportData.id, reportData.reporter_name, typeText),
        type = 'inform',
        duration = 10000,
        icon = 'fa-solid fa-bell'
    })
end)

-----------------------------------------------------------------------
-- Notification of new reply (for players)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:client:reportreplynotification', function(reportData)
    lib.notify({ 
        title = locale('cl_report_reply_notification'), 
        description = locale('cl_report_reply_notification_desc', reportData.reportId, reportData.adminName),
        type = 'inform',
        duration = 10000,
        icon = 'fa-solid fa-comment'
    })
end)
