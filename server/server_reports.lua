local RSGCore = exports['rsg-core']:GetCoreObject()

-- covers installs from before these columns existed — admin_reports itself is
-- created externally (no CREATE TABLE anywhere in this codebase), so this
-- only ever adds columns, never the table
-- self-migrating (runs in order so the ALTERs never hit a missing table)
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `admin_reports` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `report_type` VARCHAR(50) NOT NULL,
            `severity` VARCHAR(20) DEFAULT 'medium',
            `reporter_id` INT(11) NOT NULL,
            `reporter_name` VARCHAR(255) NOT NULL,
            `reporter_license` VARCHAR(255) NOT NULL,
            `reporter_steam` VARCHAR(50) DEFAULT NULL,
            `reporter_discord` VARCHAR(255) DEFAULT NULL,
            `reporter_coords` VARCHAR(255) NOT NULL,
            `reported_player_id` INT(11) DEFAULT NULL,
            `reported_player_name` VARCHAR(255) DEFAULT NULL,
            `reported_player_license` VARCHAR(255) DEFAULT NULL,
            `reported_player_discord` VARCHAR(255) DEFAULT NULL,
            `title` VARCHAR(255) NOT NULL,
            `description` TEXT NOT NULL,
            `image_url` VARCHAR(500) DEFAULT NULL,
            `status` VARCHAR(50) DEFAULT 'open',
            `assigned_admin_id` INT(11) DEFAULT NULL,
            `assigned_admin_name` VARCHAR(255) DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await("ALTER TABLE `admin_reports` ADD COLUMN IF NOT EXISTS `severity` VARCHAR(20) DEFAULT 'medium'")
    MySQL.query.await("ALTER TABLE `admin_reports` ADD COLUMN IF NOT EXISTS `reporter_steam` VARCHAR(50) DEFAULT NULL")
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `admin_report_messages` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `report_id` INT(11) NOT NULL,
            `sender_type` VARCHAR(50) NOT NULL,
            `sender_id` INT(11) NOT NULL,
            `sender_name` VARCHAR(255) NOT NULL,
            `message` TEXT NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            FOREIGN KEY (`report_id`) REFERENCES `admin_reports`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `admin_report_nearby_players` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `report_id` INT(11) NOT NULL,
            `player_id` INT(11) NOT NULL,
            `player_name` VARCHAR(255) NOT NULL,
            `player_license` VARCHAR(255) NOT NULL,
            `distance` FLOAT NOT NULL,
            PRIMARY KEY (`id`),
            FOREIGN KEY (`report_id`) REFERENCES `admin_reports`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

local MAX_TITLE, MAX_DESCRIPTION, MAX_MESSAGE = 100, 1000, 1000
local allowedReportTypes = { bug = true, player = true, question = true }
local reportCooldowns, replyCooldowns = {}, {}

AddEventHandler('playerDropped', function()
    replyCooldowns[source] = nil
end)

-- report rows store the reporter's server id at the time; only notify that id
-- if it still belongs to the same person (ids get reused after a disconnect)
local function OnlineReporter(report)
    local id = tonumber(report and report.reporter_id)
    if id and GetPlayerName(id) and RSGCore.Functions.GetIdentifier(id, 'license') == report.reporter_license then
        return id
    end
    return nil
end

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
        embeds = { embed },
        allowed_mentions = { parse = {}, roles = {} },
    }
    
    -- Add role mentions if enabled and requested
    if includeMention and Config.Reports.Discord.EnableRoleMention and Config.Reports.Discord.RolesToMention then
        local mentions = ""
        for _, roleId in ipairs(Config.Reports.Discord.RolesToMention) do
            mentions = mentions .. "<@&" .. roleId .. "> "
        end
        if mentions ~= "" then
            payload.content = mentions
            payload.allowed_mentions.roles = Config.Reports.Discord.RolesToMention
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
    
    local domain = (string.match(url, '^https?://([%w%-%.]+)') or ''):lower()
    local domainAllowed = false
    
    for _, allowedDomain in ipairs(allowedDomains) do
        if domain == allowedDomain or domain:sub(-(#allowedDomain + 1)) == '.' .. allowedDomain then
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
    
    if not Player or type(reportData) ~= 'table' then return end

    local reporterLicense = RSGCore.Functions.GetIdentifier(src, 'license')
    local now = os.time()
    if reportCooldowns[reporterLicense] and now < reportCooldowns[reporterLicense] then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('sv_report_error'), description = locale('sv_report_wait'), type = 'error' })
        return
    end

    reportData.title = CleanText(reportData.title, MAX_TITLE)
    reportData.description = CleanText(reportData.description, MAX_DESCRIPTION)
    reportData.reportedPlayerId = tonumber(reportData.reportedPlayerId)
    if not allowedReportTypes[reportData.reportType] or not reportData.title or not reportData.description then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('sv_report_error'), description = locale('sv_invalid_input'), type = 'error' })
        return
    end
    reportCooldowns[reporterLicense] = now + (Config.Reports.Cooldown or 60)

    local reporterName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local reporterDiscord = GetPlayerDiscord(src)
    local reporterSteam = RSGCore.Functions.GetIdentifier(src, 'steam')
    local coords = GetEntityCoords(GetPlayerPed(src))
    local coordsString = string.format("%.2f, %.2f, %.2f", coords.x, coords.y, coords.z)

    local allowedSeverities = { low = true, medium = true, high = true }
    local severity = allowedSeverities[reportData.severity] and reportData.severity or 'medium'
    
    local reportedPlayerName = nil
    local reportedPlayerLicense = nil
    local reportedPlayerDiscord = nil
    
    -- VALIDATION: Check if the reported player exists
    if reportData.reportedPlayerId then
        local ReportedPlayer = RSGCore.Functions.GetPlayer(reportData.reportedPlayerId)
        
        if not ReportedPlayer then
            -- The player does not exist or is not connected
            TriggerClientEvent('RSGCore:Client:Notify', src, {
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
            TriggerClientEvent('RSGCore:Client:Notify', src, {
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
    MySQL.insert('INSERT INTO `admin_reports` (report_type, reporter_id, reporter_name, reporter_license, reporter_discord, reporter_steam, reporter_coords, reported_player_id, reported_player_name, reported_player_license, reported_player_discord, title, description, image_url, status, severity) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        reportData.reportType,
        src,
        reporterName,
        reporterLicense,
        reporterDiscord,
        reporterSteam,
        coordsString,
        reportData.reportedPlayerId,
        reportedPlayerName,
        reportedPlayerLicense,
        reportedPlayerDiscord,
        reportData.title,
        reportData.description,
        reportData.imageUrl,
        'open',
        severity,
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
            TriggerClientEvent('RSGCore:Client:Notify', src, {
                title = locale('sv_report_created'),
                description = locale('sv_report_created_desc', reportId),
                type = 'success'
            })
            
            -- Notify online admins about the new report
            for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
                if RSGCore.Functions.HasPermission(playerId, reportPermissions['viewreports']) or IsPlayerAceAllowed(playerId, 'god') then
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
    
    MySQL.query('SELECT * FROM admin_reports WHERE reporter_license = ? AND status != ? ORDER BY created_at DESC', {
        reporterLicense, 'closed'
    }, function(result)
        cb(result)
    end)
end)

-----------------------------------------------------------------------
-- Get all reports (admin)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getallreports', function(source, cb)
    local src = source
    
    if not RSGCore.Functions.HasPermission(src, reportPermissions['viewreports']) and not IsPlayerAceAllowed(src, 'god') then
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
    reportId = tonumber(reportId)
    if not reportId then return cb(nil) end
    
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
        local isAdmin = RSGCore.Functions.HasPermission(src, reportPermissions['viewreports']) or IsPlayerAceAllowed(src, 'god')
        
        if report.reporter_license ~= reporterLicense and not isAdmin then
            cb(nil)
            return
        end
        
        MySQL.query('SELECT * FROM admin_report_messages WHERE report_id = ? ORDER BY created_at ASC', {
            reportId
        }, function(messages)
            for i, msg in ipairs(messages) do
                -- Handle different timestamp formats from MySQL
                if msg.created_at then
                    if type(msg.created_at) == 'number' then
                        -- It's already a Unix timestamp
                        messages[i].created_at_text = os.date('%d/%m/%Y %H:%M', msg.created_at)
                    elseif type(msg.created_at) == 'string' then
                        -- Parse MySQL TIMESTAMP format: "YYYY-MM-DD HH:MM:SS"
                        local year, month, day, hour, min, sec = msg.created_at:match("(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)")
                        if year and month and day and hour and min and sec then
                            local timestamp = os.time({
                                year = tonumber(year),
                                month = tonumber(month),
                                day = tonumber(day),
                                hour = tonumber(hour),
                                min = tonumber(min),
                                sec = tonumber(sec)
                            })
                            messages[i].created_at_text = os.date('%d/%m/%Y %H:%M', timestamp)
                        else
                            -- Fallback if parsing fails
                            messages[i].created_at_text = tostring(msg.created_at)
                        end
                    else
                        -- Unknown type, convert to string
                        messages[i].created_at_text = tostring(msg.created_at)
                    end
                else
                    messages[i].created_at_text = locale('sv_unknown')
                end
            end
            
            local function respond()
                if isAdmin then
                    MySQL.query('SELECT * FROM admin_report_nearby_players WHERE report_id = ? ORDER BY distance ASC', {
                        reportId
                    }, function(nearbyPlayers)
                        cb(report, messages, nearbyPlayers)
                    end)
                else
                    cb(report, messages, nil)
                end
            end

            -- enrich with the reporter's live discord name/avatar (works even
            -- if they're offline now, since resolution only needs the stored
            -- discord id, not an active session)
            ResolveDiscordName(report.reporter_discord, function(discordName, discordAvatarUrl)
                report.reporter_discord_name = discordName
                report.reporter_discord_avatar = discordAvatarUrl
                respond()
            end)
        end)
    end)
end)

-----------------------------------------------------------------------
-- Claim a report (admin)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:claimreport', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not RSGCore.Functions.HasPermission(src, reportPermissions['managereports']) and not IsPlayerAceAllowed(src, 'god') then
        return
    end
    if type(data) ~= 'table' or not tonumber(data.reportId) then return end
    data.reportId = tonumber(data.reportId)
    
    local adminName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    MySQL.update('UPDATE admin_reports SET status = ?, assigned_admin_id = ?, assigned_admin_name = ? WHERE id = ?', {
        'claimed',
        src,
        adminName,
        data.reportId
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('RSGCore:Client:Notify', src, {
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
            LogAdminAction('admin_action', 'low', src, locale('sv_log_claimed_report', tostring(data.reportId)), nil, nil)
        end
    end)
end)

-----------------------------------------------------------------------
-- Release a report (admin)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:releasereport', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not RSGCore.Functions.HasPermission(src, reportPermissions['managereports']) and not IsPlayerAceAllowed(src, 'god') then
        return
    end
    if type(data) ~= 'table' or not tonumber(data.reportId) then return end
    data.reportId = tonumber(data.reportId)
    
    local adminName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    MySQL.update('UPDATE admin_reports SET status = ?, assigned_admin_id = NULL, assigned_admin_name = NULL WHERE id = ?', {
        'open',
        data.reportId
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('RSGCore:Client:Notify', src, {
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
            LogAdminAction('admin_action', 'low', src, locale('sv_log_released_report', tostring(data.reportId)), nil, nil)
        end
    end)
end)

-----------------------------------------------------------------------
-- Resolve a report (admin)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:resolvereport', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not RSGCore.Functions.HasPermission(src, reportPermissions['managereports']) and not IsPlayerAceAllowed(src, 'god') then
        return
    end
    if type(data) ~= 'table' or not tonumber(data.reportId) then return end
    data.reportId = tonumber(data.reportId)
    
    local adminName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    MySQL.update('UPDATE admin_reports SET status = ? WHERE id = ?', {
        'resolved',
        data.reportId
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('RSGCore:Client:Notify', src, {
                title = locale('sv_report_resolved'),
                description = locale('sv_report_resolved_desc', data.reportId),
                type = 'success'
            })
            
            MySQL.single('SELECT reporter_id, reporter_license FROM admin_reports WHERE id = ?', { data.reportId }, function(report)
                local reporterId = OnlineReporter(report)
                if reporterId then
                    do
                        TriggerClientEvent('RSGCore:Client:Notify', reporterId, {
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
            LogAdminAction('admin_action', 'low', src, locale('sv_log_resolved_report', tostring(data.reportId)), nil, nil)
        end
    end)
end)

-----------------------------------------------------------------------
-- Delete a report (admin)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:deletereport', function(reportId, reason)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not RSGCore.Functions.HasPermission(src, reportPermissions['managereports']) and not IsPlayerAceAllowed(src, 'god') then
        return
    end
    reportId = tonumber(reportId)
    reason = CleanText(reason) or locale('sv_no_reason')
    if not reportId then return end
    
    local adminName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    MySQL.update('UPDATE admin_reports SET status = ? WHERE id = ?', {
        'closed',
        reportId
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('RSGCore:Client:Notify', src, {
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
            LogAdminAction('admin_action', 'low', src, locale('sv_log_deleted_report', tostring(reportId)), reason, nil)
        end
    end)
end)

-----------------------------------------------------------------------
-- Reply to a report
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:replyreport', function(reportId, message)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    reportId = tonumber(reportId)
    message = CleanText(message, MAX_MESSAGE)
    if not Player or not reportId or not message then return end

    local now = GetGameTimer()
    if replyCooldowns[src] and now < replyCooldowns[src] then return end
    replyCooldowns[src] = now + (Config.Reports.ReplyCooldown or 3) * 1000
    local senderType

    local senderName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    MySQL.single('SELECT * FROM admin_reports WHERE id = ?', { reportId }, function(report)
        if not report then return end
        
        local reporterLicense = RSGCore.Functions.GetIdentifier(src, 'license')
        local isAdmin = RSGCore.Functions.HasPermission(src, reportPermissions['viewreports']) or IsPlayerAceAllowed(src, 'god')
        
        if report.reporter_license ~= reporterLicense and not isAdmin then
            return
        end
        if report.status == 'closed' then
            TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('sv_report_error'), description = locale('sv_report_closed'), type = 'error' })
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
                TriggerClientEvent('RSGCore:Client:Notify', src, {
                    title = locale('sv_report_reply_sent'),
                    description = locale('sv_report_reply_sent_desc'),
                    type = 'success'
                })
                
                if senderType == 'admin' then
                    local reporterId = OnlineReporter(report)
                    if reporterId then
                        TriggerClientEvent('rsg-adminmenu:client:reportreplynotification', reporterId, {
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
                            if RSGCore.Functions.HasPermission(playerId, reportPermissions['viewreports']) or IsPlayerAceAllowed(playerId, 'god') then
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

                if senderType == 'admin' then
                    LogAdminAction('admin_action', 'low', src, locale('sv_log_replied_report', tostring(reportId)), nil, nil)
                end
            end
        end)
    end)
end)
