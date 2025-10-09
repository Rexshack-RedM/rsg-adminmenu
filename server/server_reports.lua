local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-----------------------------------------------------------------------
-- Permissions
-----------------------------------------------------------------------
local reportPermissions = {
    ['viewreports'] = 'admin',
    ['managereports'] = 'admin',
}

-----------------------------------------------------------------------
-- Discord webhook send function
-----------------------------------------------------------------------
local function SendDiscordWebhook(webhookUrl, embed, includeMention)
    if not webhookUrl or webhookUrl == "" or webhookUrl == "YOUR_WEBHOOK_URL_HERE" then
        return
    end
    
    local payload = {
        username = locale('sv_webhook_username'),
        embeds = { embed }
    }
    
    -- Add role mentions if enabled and requested
    if includeMention and Config.Reports.Discord.EnableRoleMention and Config.Reports.Discord.RolesToMention then
        local mentions = ""
        for _, roleId in ipairs(Config.Reports.Discord.RolesToMention) do
            mentions = mentions .. "<@&" .. roleId .. "> "
        end
        if mentions ~= "" then
            payload.content = mentions
        end
    end
    
    PerformHttpRequest(webhookUrl, function(err, text, headers) end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

-----------------------------------------------------------------------
-- Get a player's Discord information
-----------------------------------------------------------------------
local function GetPlayerDiscord(src)
    local identifiers = GetPlayerIdentifiers(src)
    for _, id in pairs(identifiers) do
        if string.match(id, "discord:") then
            return string.gsub(id, "discord:", "")
        end
    end
    return nil
end

-----------------------------------------------------------------------
-- Get nearby players
-----------------------------------------------------------------------
local function GetNearbyPlayers(source)
    local src = source
    local srcCoords = GetEntityCoords(GetPlayerPed(src))
    local nearbyPlayers = {}
    
    for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
        if playerId ~= src then
            local targetPed = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(srcCoords - targetCoords)
            
            if distance <= Config.Reports.NearbyDistance then
                local Player = RSGCore.Functions.GetPlayer(playerId)
                if Player then
                    table.insert(nearbyPlayers, {
                        player_id = playerId,
                        player_name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                        player_license = RSGCore.Functions.GetIdentifier(playerId, 'license'),
                        distance = distance
                    })
                end
            end
        end
    end
    
    return nearbyPlayers
end

-----------------------------------------------------------------------
-- Sanitize and validate image URL
-----------------------------------------------------------------------
local function ValidateImageUrl(url)
    if not url or url == '' then
        return true, nil  -- Empty URL is allowed
    end
    
    -- Check URL length
    if #url > 500 then
        return false, 'sv_report_url_too_long'
    end
    
    -- Check if URL starts with http:// or https://
    if not string.match(url, '^https?://') then
        return false, 'sv_report_url_invalid_protocol'
    end
    
    -- Check for valid URL pattern
    if not string.match(url, '^https?://[%w%-%.]+%.[%w]+') then
        return false, 'sv_report_url_invalid_format'
    end
    
    -- Optional: Whitelist allowed domains (Imgur, Discord CDN, etc.)
    local allowedDomains = {
        'imgur.com',
        'i.imgur.com',
        'cdn.discordapp.com',
        'media.discordapp.net',
        'i.gyazo.com',
        'prnt.sc'
    }
    
    local domain = string.match(url, '^https?://([%w%-%.]+)')
    local domainAllowed = false
    
    for _, allowedDomain in ipairs(allowedDomains) do
        if string.find(domain, allowedDomain, 1, true) then
            domainAllowed = true
            break
        end
    end
    
    if not domainAllowed then
        return false, 'sv_report_url_domain_not_allowed'
    end
    
    return true, url
end

-----------------------------------------------------------------------
-- Create a new report
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:createreport', function(reportData)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local reporterName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local reporterLicense = RSGCore.Functions.GetIdentifier(src, 'license')
    local reporterDiscord = GetPlayerDiscord(src)
    local coords = GetEntityCoords(GetPlayerPed(src))
    local coordsString = string.format("%.2f, %.2f, %.2f", coords.x, coords.y, coords.z)
    
    local reportedPlayerName = nil
    local reportedPlayerLicense = nil
    local reportedPlayerDiscord = nil
    
    -- VALIDATION: Check if the reported player exists
    if reportData.reportedPlayerId then
        local ReportedPlayer = RSGCore.Functions.GetPlayer(reportData.reportedPlayerId)
        
        if not ReportedPlayer then
            -- The player does not exist or is not connected
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_report_player_not_found'),
                description = locale('sv_report_player_not_found_desc'),
                type = 'error'
            })
            return
        end
        
        reportedPlayerName = ReportedPlayer.PlayerData.charinfo.firstname .. ' ' .. ReportedPlayer.PlayerData.charinfo.lastname
        reportedPlayerLicense = RSGCore.Functions.GetIdentifier(reportData.reportedPlayerId, 'license')
        reportedPlayerDiscord = GetPlayerDiscord(reportData.reportedPlayerId)
    end
    
    -- VALIDATION: Validate image URL if provided
    if reportData.imageUrl and reportData.imageUrl ~= '' then
        local isValid, validatedUrl = ValidateImageUrl(reportData.imageUrl)
        
        if not isValid then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_report_error'),
                description = locale(validatedUrl),  -- validatedUrl contains the locale key error
                type = 'error'
            })
            return
        end
        
        reportData.imageUrl = validatedUrl
    end
    
    local nearbyPlayers = GetNearbyPlayers(src)
    
    -- Insert the report into the database
    MySQL.insert('INSERT INTO `admin_reports` (report_type, reporter_id, reporter_name, reporter_license, reporter_discord, reporter_coords, reported_player_id, reported_player_name, reported_player_license, reported_player_discord, title, description, image_url, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        reportData.reportType,
        src,
        reporterName,
        reporterLicense,
        reporterDiscord,
        coordsString,
        reportData.reportedPlayerId,
        reportedPlayerName,
        reportedPlayerLicense,
        reportedPlayerDiscord,
        reportData.title,
        reportData.description,
        reportData.imageUrl,
        'open'
    }, function(reportId)
        if reportId then
            -- Insert nearby players
            for _, player in ipairs(nearbyPlayers) do
                MySQL.insert('INSERT INTO admin_report_nearby_players (report_id, player_id, player_name, player_license, distance) VALUES (?, ?, ?, ?, ?)', {
                    reportId,
                    player.player_id,
                    player.player_name,
                    player.player_license,
                    player.distance
                })
            end
            
            -- Notify the reporter
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_report_created'),
                description = locale('sv_report_created_desc', reportId),
                type = 'success'
            })
            
            -- Notify online admins about the new report
            for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
                if RSGCore.Functions.HasPermission(playerId, reportPermissions['viewreports']) or IsPlayerAceAllowed(playerId, 'command') then
                    TriggerClientEvent('rsg-adminmenu:client:newreportnotification', playerId, {
                        id = reportId,
                        reporter_name = reporterName,
                        report_type = reportData.reportType
                    })
                end
            end
            
            -- Determine webhook URL based on report type
            local webhookUrl = Config.Reports.Webhooks.Main
            if reportData.reportType == 'bug' and Config.Reports.Webhooks.Bug ~= "" then
                webhookUrl = Config.Reports.Webhooks.Bug
            elseif reportData.reportType == 'player' and Config.Reports.Webhooks.Player ~= "" then
                webhookUrl = Config.Reports.Webhooks.Player
            elseif reportData.reportType == 'question' and Config.Reports.Webhooks.Question ~= "" then
                webhookUrl = Config.Reports.Webhooks.Question
            end
            
            -- Create Discord webhook embed
            local typeText = locale('sv_report_type_' .. reportData.reportType)
            local embed = {
                title = locale('sv_webhook_new_report', reportId),
                color = Config.Reports.WebhookColors[reportData.reportType] or 3447003,
                fields = {
                    { name = locale('sv_webhook_field_type'), value = typeText, inline = true },
                    { name = locale('sv_webhook_field_reporter'), value = reporterName .. ' (ID: ' .. src .. ')', inline = true },
                    { name = locale('sv_webhook_field_title'), value = reportData.title, inline = false },
                    { name = locale('sv_webhook_field_description'), value = reportData.description, inline = false },
                    { name = locale('sv_webhook_field_coords'), value = coordsString, inline = false },
                    { name = locale('sv_webhook_field_license'), value = reporterLicense or locale('sv_webhook_na'), inline = true },
                    { name = locale('sv_webhook_field_discord'), value = reporterDiscord and ('<@' .. reporterDiscord .. '>') or locale('sv_webhook_na'), inline = true },
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
            
            -- Add reported player information if available
            if reportedPlayerName then
                table.insert(embed.fields, { name = locale('sv_webhook_field_reported_player'), value = reportedPlayerName .. ' (ID: ' .. reportData.reportedPlayerId .. ')', inline = false })
                table.insert(embed.fields, { name = locale('sv_webhook_field_reported_license'), value = reportedPlayerLicense or locale('sv_webhook_na'), inline = true })
                table.insert(embed.fields, { name = locale('sv_webhook_field_reported_discord'), value = reportedPlayerDiscord and ('<@' .. reportedPlayerDiscord .. '>') or locale('sv_webhook_na'), inline = true })
            end
            
            -- Add image proof if provided
            if reportData.imageUrl and reportData.imageUrl ~= '' then
                embed.image = { url = reportData.imageUrl }
                table.insert(embed.fields, { name = locale('sv_webhook_field_proof'), value = '[' .. locale('sv_webhook_click_here') .. '](' .. reportData.imageUrl .. ')', inline = false })
            end
            
            -- Add nearby players information (limit to 10)
            if #nearbyPlayers > 0 then
                local nearbyText = ''
                for i, player in ipairs(nearbyPlayers) do
                    nearbyText = nearbyText .. player.player_name .. ' (ID: ' .. player.player_id .. ') - ' .. string.format("%.2f", player.distance) .. 'm\n'
                    if i >= 10 then break end
                end
                table.insert(embed.fields, { name = locale('sv_webhook_field_nearby_players', #nearbyPlayers), value = nearbyText, inline = false })
            end
            
            -- Send Discord webhook
            SendDiscordWebhook(webhookUrl, embed, true)
            
            -- Log the report creation
            TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_report_log_created'), 'blue', locale('sv_report_log_created_desc', reporterName, src, reportId, reportData.reportType), true)
        end
    end)
end)

-----------------------------------------------------------------------
-- Get my reports (player)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getmyreports', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then 
        cb(nil)
        return 
    end
    
    local reporterLicense = RSGCore.Functions.GetIdentifier(src, 'license')
    
    MySQL.query('SELECT * FROM admin_reports WHERE reporter_license = ? ORDER BY created_at DESC', {
        reporterLicense
    }, function(result)
        cb(result)
    end)
end)

-----------------------------------------------------------------------
-- Get all reports (admin)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getallreports', function(source, cb)
    local src = source
    
    if not RSGCore.Functions.HasPermission(src, reportPermissions['viewreports']) and not IsPlayerAceAllowed(src, 'command') then
        cb(nil)
        return
    end
    
    MySQL.query('SELECT * FROM admin_reports WHERE status != ? ORDER BY created_at DESC', {
        'closed'
    }, function(result)
        cb(result)
    end)
end)

-----------------------------------------------------------------------
-- Get report details
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getreportdetails', function(source, cb, reportId)
    local src = source
    
    MySQL.single('SELECT * FROM admin_reports WHERE id = ?', { reportId }, function(report)
        if not report then
            cb(nil)
            return
        end
        
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then
            cb(nil)
            return
        end
        
        local reporterLicense = RSGCore.Functions.GetIdentifier(src, 'license')
        local isAdmin = RSGCore.Functions.HasPermission(src, reportPermissions['viewreports']) or IsPlayerAceAllowed(src, 'command')
        
        if report.reporter_license ~= reporterLicense and not isAdmin then
            cb(nil)
            return
        end
        
        MySQL.query('SELECT * FROM admin_report_messages WHERE report_id = ? ORDER BY created_at ASC', {
            reportId
        }, function(messages)
            for i, msg in ipairs(messages) do
                messages[i].created_at_text = os.date('%d/%m/%Y %H:%M', os.time({
                    year = tonumber(os.date("%Y", msg.created_at)),
                    month = tonumber(os.date("%m", msg.created_at)),
                    day = tonumber(os.date("%d", msg.created_at)),
                    hour = tonumber(os.date("%H", msg.created_at)),
                    min = tonumber(os.date("%M", msg.created_at)),
                    sec = tonumber(os.date("%S", msg.created_at))
                }))
            end
            
            if isAdmin then
                MySQL.query('SELECT * FROM admin_report_nearby_players WHERE report_id = ? ORDER BY distance ASC', {
                    reportId
                }, function(nearbyPlayers)
                    cb(report, messages, nearbyPlayers)
                end)
            else
                cb(report, messages, nil)
            end
        end)
    end)
end)

-----------------------------------------------------------------------
-- Claim a report (admin)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:claimreport', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not RSGCore.Functions.HasPermission(src, reportPermissions['managereports']) and not IsPlayerAceAllowed(src, 'command') then
        return
    end
    
    local adminName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    MySQL.update('UPDATE admin_reports SET status = ?, assigned_admin_id = ?, assigned_admin_name = ? WHERE id = ?', {
        'claimed',
        src,
        adminName,
        data.reportId
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_report_claimed'),
                description = locale('sv_report_claimed_desc', data.reportId),
                type = 'success'
            })
            
            local embed = {
                title = locale('sv_webhook_claimed_report', data.reportId),
                color = Config.Reports.WebhookColors.claimed,
                fields = {
                    { name = locale('sv_webhook_field_admin'), value = adminName .. ' (ID: ' .. src .. ')', inline = false },
                    { name = locale('sv_webhook_field_report_id'), value = '#' .. data.reportId, inline = false },
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
            SendDiscordWebhook(Config.Reports.Webhooks.Main, embed)
            
            TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_report_log_claimed'), 'yellow', locale('sv_report_log_claimed_desc', adminName, src, data.reportId), true)
        end
    end)
end)

-----------------------------------------------------------------------
-- Release a report (admin)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:releasereport', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not RSGCore.Functions.HasPermission(src, reportPermissions['managereports']) and not IsPlayerAceAllowed(src, 'command') then
        return
    end
    
    local adminName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    MySQL.update('UPDATE admin_reports SET status = ?, assigned_admin_id = NULL, assigned_admin_name = NULL WHERE id = ?', {
        'open',
        data.reportId
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_report_released'),
                description = locale('sv_report_released_desc', data.reportId),
                type = 'success'
            })
            
            local embed = {
                title = locale('sv_webhook_released_report', data.reportId),
                color = Config.Reports.WebhookColors.open,
                fields = {
                    { name = locale('sv_webhook_field_admin'), value = adminName .. ' (ID: ' .. src .. ')', inline = false },
                    { name = locale('sv_webhook_field_report_id'), value = '#' .. data.reportId, inline = false },
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
            SendDiscordWebhook(Config.Reports.Webhooks.Main, embed)
            
            TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_report_log_released'), 'blue', locale('sv_report_log_released_desc', adminName, src, data.reportId), true)
        end
    end)
end)

-----------------------------------------------------------------------
-- Resolve a report (admin)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:resolvereport', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not RSGCore.Functions.HasPermission(src, reportPermissions['managereports']) and not IsPlayerAceAllowed(src, 'command') then
        return
    end
    
    local adminName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    MySQL.update('UPDATE admin_reports SET status = ? WHERE id = ?', {
        'resolved',
        data.reportId
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_report_resolved'),
                description = locale('sv_report_resolved_desc', data.reportId),
                type = 'success'
            })
            
            MySQL.single('SELECT reporter_id FROM admin_reports WHERE id = ?', { data.reportId }, function(report)
                if report and report.reporter_id then
                    local reporterPlayer = RSGCore.Functions.GetPlayer(report.reporter_id)
                    if reporterPlayer then
                        TriggerClientEvent('ox_lib:notify', report.reporter_id, {
                            title = locale('sv_report_resolved_player'),
                            description = locale('sv_report_resolved_player_desc', data.reportId),
                            type = 'success',
                            duration = 10000
                        })
                    end
                end
            end)
            
            local embed = {
                title = locale('sv_webhook_resolved_report', data.reportId),
                color = Config.Reports.WebhookColors.resolved,
                fields = {
                    { name = locale('sv_webhook_field_admin'), value = adminName .. ' (ID: ' .. src .. ')', inline = false },
                    { name = locale('sv_webhook_field_report_id'), value = '#' .. data.reportId, inline = false },
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
            SendDiscordWebhook(Config.Reports.Webhooks.Main, embed)
            
            TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_report_log_resolved'), 'green', locale('sv_report_log_resolved_desc', adminName, src, data.reportId), true)
        end
    end)
end)

-----------------------------------------------------------------------
-- Delete a report (admin)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:deletereport', function(reportId, reason)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not RSGCore.Functions.HasPermission(src, reportPermissions['managereports']) and not IsPlayerAceAllowed(src, 'command') then
        return
    end
    
    local adminName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    MySQL.update('UPDATE admin_reports SET status = ? WHERE id = ?', {
        'closed',
        reportId
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_report_deleted'),
                description = locale('sv_report_deleted_desc', reportId),
                type = 'success'
            })
            
            local embed = {
                title = locale('sv_webhook_deleted_report', reportId),
                color = Config.Reports.WebhookColors.closed,
                fields = {
                    { name = locale('sv_webhook_field_admin'), value = adminName .. ' (ID: ' .. src .. ')', inline = false },
                    { name = locale('sv_webhook_field_report_id'), value = '#' .. reportId, inline = false },
                    { name = locale('sv_webhook_field_reason'), value = reason, inline = false },
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
            SendDiscordWebhook(Config.Reports.Webhooks.Main, embed)
            
            TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_report_log_deleted'), 'red', locale('sv_report_log_deleted_desc', adminName, src, reportId, reason), true)
        end
    end)
end)

-----------------------------------------------------------------------
-- Reply to a report
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:replyreport', function(reportId, message, senderType)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local senderName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    MySQL.single('SELECT * FROM admin_reports WHERE id = ?', { reportId }, function(report)
        if not report then return end
        
        local reporterLicense = RSGCore.Functions.GetIdentifier(src, 'license')
        local isAdmin = RSGCore.Functions.HasPermission(src, reportPermissions['viewreports']) or IsPlayerAceAllowed(src, 'command')
        
        if report.reporter_license ~= reporterLicense and not isAdmin then
            return
        end
        
        if isAdmin then
            senderType = 'admin'
        else
            senderType = 'player'
        end
        
        MySQL.insert('INSERT INTO admin_report_messages (report_id, sender_type, sender_id, sender_name, message) VALUES (?, ?, ?, ?, ?)', {
            reportId,
            senderType,
            src,
            senderName,
            message
        }, function(messageId)
            if messageId then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('sv_report_reply_sent'),
                    description = locale('sv_report_reply_sent_desc'),
                    type = 'success'
                })
                
                if senderType == 'admin' then
                    local reporterPlayer = RSGCore.Functions.GetPlayer(report.reporter_id)
                    if reporterPlayer then
                        TriggerClientEvent('rsg-adminmenu:client:reportreplynotification', report.reporter_id, {
                            reportId = reportId,
                            adminName = senderName
                        })
                    end
                else
                    if report.assigned_admin_id then
                        local assignedAdmin = RSGCore.Functions.GetPlayer(report.assigned_admin_id)
                        if assignedAdmin then
                            TriggerClientEvent('rsg-adminmenu:client:newreportnotification', report.assigned_admin_id, {
                                id = reportId,
                                reporter_name = senderName,
                                report_type = 'response'
                            })
                        end
                    else
                        for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
                            if RSGCore.Functions.HasPermission(playerId, reportPermissions['viewreports']) or IsPlayerAceAllowed(playerId, 'command') then
                                TriggerClientEvent('rsg-adminmenu:client:newreportnotification', playerId, {
                                    id = reportId,
                                    reporter_name = senderName,
                                    report_type = 'response'
                                })
                            end
                        end
                    end
                end
                
                local embed = {
                    title = locale('sv_webhook_new_message', reportId),
                    color = 3447003,
                    fields = {
                        { name = locale('sv_webhook_field_sender'), value = senderName .. ' (' .. senderType .. ')', inline = false },
                        { name = locale('sv_webhook_field_report_id'), value = '#' .. reportId, inline = false },
                        { name = locale('sv_webhook_field_message'), value = message, inline = false },
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }
                SendDiscordWebhook(Config.Reports.Webhooks.Main, embed)
            end
        end)
    end)
end)
