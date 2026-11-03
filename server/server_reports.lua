local RSGCore = exports['rsg-core']:GetCoreObject()

local REPORT_TYPES = { bug = true, player = true, question = true }
local SEVERITIES = { low = true, medium = true, high = true }
local MAX_TITLE, MAX_DESCRIPTION, MAX_MESSAGE, MAX_REASON = 100, 2000, 1000, 255
local REPLY_COOLDOWN = 3 -- seconds between replies from one player
local ALLOWED_IMAGE_DOMAINS = { 'imgur.com', 'cdn.discordapp.com', 'media.discordapp.net', 'gyazo.com', 'prnt.sc' }

local reportCooldowns = {} -- license -> os.time() of last report
local replyCooldowns = {}  -- source -> os.time() of last reply

local function CanViewReports(src)
    return HasAdminPermission(src, 'reports')
end

-----------------------------------------------------------------------
-- Discord webhook send function
-----------------------------------------------------------------------
-- Discord rejects embeds with an empty field or a value over 1024 chars
local function EmbedValue(value)
    local text = tostring(value or '')
    if text == '' then return locale('sv_webhook_na') end
    return #text > 1024 and (text:sub(1, 1021) .. '...') or text
end

local function SendDiscordWebhook(webhookUrl, embed, includeMention)
    if not IsWebhookSet(webhookUrl) then return end

    for _, field in ipairs(embed.fields or {}) do
        field.value = EmbedValue(field.value)
    end

    local payload = {
        username = locale('sv_webhook_username'),
        embeds = { embed },
    }

    local discordCfg = Config.Reports.Discord
    if includeMention and discordCfg.EnableRoleMention and discordCfg.RolesToMention then
        local mentions = {}
        for _, roleId in ipairs(discordCfg.RolesToMention) do
            if tostring(roleId):match('^%d+$') then -- skip the placeholder text
                mentions[#mentions + 1] = '<@&' .. roleId .. '>'
            end
        end
        if #mentions > 0 then
            payload.content = table.concat(mentions, ' ')
        end
    end

    PerformHttpRequest(webhookUrl, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function StatusEmbed(titleKey, reportId, color, adminName, src, extraFields)
    local fields = {
        { name = locale('sv_webhook_field_admin'), value = adminName .. ' (ID: ' .. src .. ')', inline = false },
        { name = locale('sv_webhook_field_report_id'), value = '#' .. reportId, inline = false },
    }
    for _, f in ipairs(extraFields or {}) do fields[#fields + 1] = f end
    return {
        title = locale(titleKey, reportId),
        color = color,
        fields = fields,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
end

local function GetPlayerDiscord(src)
    local discord = RSGCore.Functions.GetIdentifier(src, 'discord')
    return discord and discord:gsub('discord:', '') or nil
end

local function CharName(Player)
    return Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
end

-- the stored reporter_id is only a server-id snapshot, so confirm it is still
-- the same person (license) before notifying whoever holds that id now
local function GetOnlineReporter(report)
    local id = tonumber(report.reporter_id)
    if not id or not RSGCore.Functions.GetPlayer(id) then return nil end
    if RSGCore.Functions.GetIdentifier(id, 'license') ~= report.reporter_license then return nil end
    return id
end

local function NotifyStaff(payload)
    for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
        if CanViewReports(playerId) then
            TriggerClientEvent('rsg-adminmenu:client:newreportnotification', playerId, payload)
        end
    end
end

-----------------------------------------------------------------------
-- Get nearby players
-----------------------------------------------------------------------
local function GetNearbyPlayers(src)
    local srcCoords = GetEntityCoords(GetPlayerPed(src))
    local nearbyPlayers = {}

    for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
        if playerId ~= src then
            local distance = #(srcCoords - GetEntityCoords(GetPlayerPed(playerId)))
            if distance <= Config.Reports.NearbyDistance then
                local Player = RSGCore.Functions.GetPlayer(playerId)
                if Player then
                    nearbyPlayers[#nearbyPlayers + 1] = {
                        player_id = playerId,
                        player_name = CharName(Player),
                        player_license = RSGCore.Functions.GetIdentifier(playerId, 'license') or '',
                        distance = distance,
                    }
                end
            end
        end
    end

    table.sort(nearbyPlayers, function(a, b) return a.distance < b.distance end)
    return nearbyPlayers
end

-----------------------------------------------------------------------
-- Sanitize and validate image URL (https only, allow-listed hosts)
-----------------------------------------------------------------------
local function ValidateImageUrl(url)
    if #url > 500 then return false, 'sv_report_url_too_long' end
    if not url:match('^https?://') then return false, 'sv_report_url_invalid_protocol' end

    local host = url:match('^https?://([%w%-%.]+)')
    if not host or not host:find('%.') then return false, 'sv_report_url_invalid_format' end
    host = host:lower()

    -- exact host or a subdomain of it ("evilimgur.com" / "imgur.com.evil.net" don't pass)
    for _, domain in ipairs(ALLOWED_IMAGE_DOMAINS) do
        if host == domain or host:sub(-(#domain + 1)) == '.' .. domain then
            return true, url
        end
    end
    return false, 'sv_report_url_domain_not_allowed'
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
    if reportCooldowns[reporterLicense] and now - reportCooldowns[reporterLicense] < Config.Reports.Cooldown then
        return NotifyPlayer(src, locale('cl_report_cooldown_title'), locale('cl_report_cooldown_desc'), 'error')
    end

    local reportType = REPORT_TYPES[reportData.reportType] and reportData.reportType or nil
    local title = SanitizeText(reportData.title, MAX_TITLE)
    local description = SanitizeText(reportData.description, MAX_DESCRIPTION)
    if not reportType or not title or not description then
        return NotifyPlayer(src, locale('sv_report_error'), locale('sv_invalid_value'), 'error')
    end
    local severity = SEVERITIES[reportData.severity] and reportData.severity or 'medium'

    local reporterName = CharName(Player)
    local reporterDiscord = GetPlayerDiscord(src)
    local coords = GetEntityCoords(GetPlayerPed(src))
    local coordsString = string.format('%.2f, %.2f, %.2f', coords.x, coords.y, coords.z)

    local reportedId, reportedPlayerName, reportedPlayerLicense, reportedPlayerDiscord = nil, nil, nil, nil
    if reportData.reportedPlayerId and reportData.reportedPlayerId ~= '' then
        reportedId = tonumber(reportData.reportedPlayerId)
        local ReportedPlayer = reportedId and reportedId ~= src and RSGCore.Functions.GetPlayer(reportedId)
        if not ReportedPlayer then
            return NotifyPlayer(src, locale('sv_report_player_not_found'), locale('sv_report_player_not_found_desc'), 'error')
        end
        reportedPlayerName = CharName(ReportedPlayer)
        reportedPlayerLicense = RSGCore.Functions.GetIdentifier(reportedId, 'license')
        reportedPlayerDiscord = GetPlayerDiscord(reportedId)
    end

    local imageUrl = SanitizeText(reportData.imageUrl, 501)
    if imageUrl then
        local isValid, result = ValidateImageUrl(imageUrl)
        if not isValid then
            return NotifyPlayer(src, locale('sv_report_error'), locale(result), 'error')
        end
        imageUrl = result
    end

    reportCooldowns[reporterLicense] = now
    local nearbyPlayers = GetNearbyPlayers(src)

    MySQL.insert('INSERT INTO `admin_reports` (report_type, reporter_id, reporter_name, reporter_license, reporter_discord, reporter_steam, reporter_coords, reported_player_id, reported_player_name, reported_player_license, reported_player_discord, title, description, image_url, status, severity) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        reportType, src, reporterName, reporterLicense, reporterDiscord, RSGCore.Functions.GetIdentifier(src, 'steam'), coordsString,
        reportedId, reportedPlayerName, reportedPlayerLicense, reportedPlayerDiscord,
        title, description, imageUrl, 'open', severity,
    }, function(reportId)
        if not reportId then
            reportCooldowns[reporterLicense] = nil
            return NotifyPlayer(src, locale('sv_report_error'), locale('sv_report_failed'), 'error')
        end

        for _, player in ipairs(nearbyPlayers) do
            MySQL.insert('INSERT INTO admin_report_nearby_players (report_id, player_id, player_name, player_license, distance) VALUES (?, ?, ?, ?, ?)', {
                reportId, player.player_id, player.player_name, player.player_license, player.distance,
            })
        end

        NotifyPlayer(src, locale('sv_report_created'), locale('sv_report_created_desc', reportId), 'success')
        NotifyStaff({ id = reportId, reporter_name = reporterName, report_type = reportType })

        local webhooks = Config.Reports.Webhooks
        local typeWebhook = ({ bug = webhooks.Bug, player = webhooks.Player, question = webhooks.Question })[reportType]
        local webhookUrl = IsWebhookSet(typeWebhook) and typeWebhook or webhooks.Main

        local embed = {
            title = locale('sv_webhook_new_report', reportId),
            color = Config.Reports.WebhookColors[reportType] or 3447003,
            fields = {
                { name = locale('sv_webhook_field_type'), value = locale('sv_report_type_' .. reportType), inline = true },
                { name = locale('sv_webhook_field_reporter'), value = reporterName .. ' (ID: ' .. src .. ')', inline = true },
                { name = locale('sv_webhook_field_title'), value = title, inline = false },
                { name = locale('sv_webhook_field_description'), value = description, inline = false },
                { name = locale('sv_webhook_field_coords'), value = coordsString, inline = false },
                { name = locale('sv_webhook_field_license'), value = reporterLicense, inline = true },
                { name = locale('sv_webhook_field_discord'), value = reporterDiscord and ('<@' .. reporterDiscord .. '>'), inline = true },
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        }

        if reportedPlayerName then
            embed.fields[#embed.fields + 1] = { name = locale('sv_webhook_field_reported_player'), value = reportedPlayerName .. ' (ID: ' .. reportedId .. ')', inline = false }
            embed.fields[#embed.fields + 1] = { name = locale('sv_webhook_field_reported_license'), value = reportedPlayerLicense, inline = true }
            embed.fields[#embed.fields + 1] = { name = locale('sv_webhook_field_reported_discord'), value = reportedPlayerDiscord and ('<@' .. reportedPlayerDiscord .. '>'), inline = true }
        end

        if imageUrl then
            embed.image = { url = imageUrl }
            embed.fields[#embed.fields + 1] = { name = locale('sv_webhook_field_proof'), value = '[' .. locale('sv_webhook_click_here') .. '](' .. imageUrl .. ')', inline = false }
        end

        if #nearbyPlayers > 0 then
            local lines = {}
            for i, player in ipairs(nearbyPlayers) do
                if i > 10 then break end
                lines[#lines + 1] = player.player_name .. ' (ID: ' .. player.player_id .. ') - ' .. string.format('%.2f', player.distance) .. 'm'
            end
            embed.fields[#embed.fields + 1] = { name = locale('sv_webhook_field_nearby_players', #nearbyPlayers), value = table.concat(lines, '\n'), inline = false }
        end

        SendDiscordWebhook(webhookUrl, embed, true)
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_report_log_created'), 'blue', locale('sv_report_log_created_desc', reporterName, src, reportId, reportType), true)
    end)
end)

-----------------------------------------------------------------------
-- Get my reports (player)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getmyreports', function(source, cb)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return cb(nil) end

    MySQL.query('SELECT * FROM admin_reports WHERE reporter_license = ? AND status != ? ORDER BY created_at DESC', {
        RSGCore.Functions.GetIdentifier(src, 'license'), 'closed',
    }, function(result)
        cb(result)
    end)
end)

-----------------------------------------------------------------------
-- Get all reports (admin)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getallreports', function(source, cb)
    if not CanViewReports(source) then return cb(nil) end

    MySQL.query('SELECT * FROM admin_reports WHERE status != ? ORDER BY created_at DESC', { 'closed' }, function(result)
        cb(result)
    end)
end)

-----------------------------------------------------------------------
-- Get report details
-----------------------------------------------------------------------
local function FormatTimestamp(value)
    if type(value) == 'number' then
        -- oxmysql returns TIMESTAMP columns as epoch milliseconds
        return os.date('%d/%m/%Y %H:%M', value > 1e11 and math.floor(value / 1000) or value)
    end
    local year, month, day, hour, min, sec = tostring(value or ''):match('(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)')
    if not year then return value and tostring(value) or locale('sv_unknown') end
    return os.date('%d/%m/%Y %H:%M', os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec) }))
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getreportdetails', function(source, cb, reportId)
    local src = source
    reportId = tonumber(reportId)
    if not reportId or not RSGCore.Functions.GetPlayer(src) then return cb(nil) end

    MySQL.single('SELECT * FROM admin_reports WHERE id = ?', { reportId }, function(report)
        if not report then return cb(nil) end

        local isAdmin = CanViewReports(src)
        if report.reporter_license ~= RSGCore.Functions.GetIdentifier(src, 'license') and not isAdmin then
            return cb(nil)
        end

        MySQL.query('SELECT * FROM admin_report_messages WHERE report_id = ? ORDER BY created_at ASC', { reportId }, function(messages)
            messages = messages or {}
            for _, msg in ipairs(messages) do
                msg.created_at_text = FormatTimestamp(msg.created_at)
            end

            local function respond()
                if not isAdmin then return cb(report, messages, nil) end
                MySQL.query('SELECT * FROM admin_report_nearby_players WHERE report_id = ? ORDER BY distance ASC', { reportId }, function(nearbyPlayers)
                    cb(report, messages, nearbyPlayers)
                end)
            end

            -- enrich with the reporter's discord name/avatar (works offline, only needs the stored id)
            ResolveDiscordName(report.reporter_discord, function(discordName, discordAvatarUrl)
                report.reporter_discord_name = discordName
                report.reporter_discord_avatar = discordAvatarUrl
                respond()
            end)
        end)
    end)
end)

-----------------------------------------------------------------------
-- staff status changes: claim / release / resolve / delete (close)
-----------------------------------------------------------------------
-- validates permission + report id; returns the admin's name and the numeric id, or nil
local function PrepareStaffAction(src, reportId)
    if not CanViewReports(src) then return nil end
    local Player = RSGCore.Functions.GetPlayer(src)
    reportId = tonumber(reportId)
    if not Player or not reportId then return nil end
    return CharName(Player), reportId
end

RegisterNetEvent('rsg-adminmenu:server:claimreport', function(data)
    local src = source
    local adminName, reportId = PrepareStaffAction(src, type(data) == 'table' and data.reportId)
    if not adminName then return end

    MySQL.update('UPDATE admin_reports SET status = ?, assigned_admin_id = ?, assigned_admin_name = ? WHERE id = ? AND status != ?', {
        'claimed', src, adminName, reportId, 'closed',
    }, function(affectedRows)
        if (affectedRows or 0) == 0 then return end
        NotifyPlayer(src, locale('sv_report_claimed'), locale('sv_report_claimed_desc', reportId), 'success')
        SendDiscordWebhook(Config.Reports.Webhooks.Main, StatusEmbed('sv_webhook_claimed_report', reportId, Config.Reports.WebhookColors.claimed, adminName, src))
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_report_log_claimed'), 'yellow', locale('sv_report_log_claimed_desc', adminName, src, reportId), true)
        LogAdminAction('admin_action', 'low', src, locale('sv_log_claimed_report', tostring(reportId)), nil, nil)
    end)
end)

RegisterNetEvent('rsg-adminmenu:server:releasereport', function(data)
    local src = source
    local adminName, reportId = PrepareStaffAction(src, type(data) == 'table' and data.reportId)
    if not adminName then return end

    MySQL.update('UPDATE admin_reports SET status = ?, assigned_admin_id = NULL, assigned_admin_name = NULL WHERE id = ? AND status != ?', {
        'open', reportId, 'closed',
    }, function(affectedRows)
        if (affectedRows or 0) == 0 then return end
        NotifyPlayer(src, locale('sv_report_released'), locale('sv_report_released_desc', reportId), 'success')
        SendDiscordWebhook(Config.Reports.Webhooks.Main, StatusEmbed('sv_webhook_released_report', reportId, Config.Reports.WebhookColors.open, adminName, src))
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_report_log_released'), 'blue', locale('sv_report_log_released_desc', adminName, src, reportId), true)
        LogAdminAction('admin_action', 'low', src, locale('sv_log_released_report', tostring(reportId)), nil, nil)
    end)
end)

RegisterNetEvent('rsg-adminmenu:server:resolvereport', function(data)
    local src = source
    local adminName, reportId = PrepareStaffAction(src, type(data) == 'table' and data.reportId)
    if not adminName then return end

    MySQL.update('UPDATE admin_reports SET status = ? WHERE id = ? AND status != ?', { 'resolved', reportId, 'closed' }, function(affectedRows)
        if (affectedRows or 0) == 0 then return end
        NotifyPlayer(src, locale('sv_report_resolved'), locale('sv_report_resolved_desc', reportId), 'success')

        MySQL.single('SELECT reporter_id, reporter_license FROM admin_reports WHERE id = ?', { reportId }, function(report)
            local reporter = report and GetOnlineReporter(report)
            if reporter then
                NotifyPlayer(reporter, locale('sv_report_resolved_player'), locale('sv_report_resolved_player_desc', reportId), 'success', 10000)
            end
        end)

        SendDiscordWebhook(Config.Reports.Webhooks.Main, StatusEmbed('sv_webhook_resolved_report', reportId, Config.Reports.WebhookColors.resolved, adminName, src))
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_report_log_resolved'), 'green', locale('sv_report_log_resolved_desc', adminName, src, reportId), true)
        LogAdminAction('admin_action', 'low', src, locale('sv_log_resolved_report', tostring(reportId)), nil, nil)
    end)
end)

RegisterNetEvent('rsg-adminmenu:server:deletereport', function(reportId, reason)
    local src = source
    local adminName
    adminName, reportId = PrepareStaffAction(src, reportId)
    if not adminName then return end
    reason = SanitizeText(reason, MAX_REASON) or locale('sv_no_reason')

    MySQL.update('UPDATE admin_reports SET status = ? WHERE id = ?', { 'closed', reportId }, function(affectedRows)
        if (affectedRows or 0) == 0 then return end
        NotifyPlayer(src, locale('sv_report_deleted'), locale('sv_report_deleted_desc', reportId), 'success')
        SendDiscordWebhook(Config.Reports.Webhooks.Main, StatusEmbed('sv_webhook_deleted_report', reportId, Config.Reports.WebhookColors.closed, adminName, src, {
            { name = locale('sv_webhook_field_reason'), value = reason, inline = false },
        }))
        TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', locale('sv_report_log_deleted'), 'red', locale('sv_report_log_deleted_desc', adminName, src, reportId, reason), true)
        LogAdminAction('admin_action', 'low', src, locale('sv_log_deleted_report', tostring(reportId)), reason, nil)
    end)
end)

-----------------------------------------------------------------------
-- Reply to a report (reporter or staff; sender type is decided here)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:replyreport', function(reportId, message)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    reportId = tonumber(reportId)
    message = SanitizeText(message, MAX_MESSAGE)
    if not Player or not reportId or not message then return end

    local now = os.time()
    if replyCooldowns[src] and now - replyCooldowns[src] < REPLY_COOLDOWN then return end
    replyCooldowns[src] = now

    local senderName = CharName(Player)

    MySQL.single('SELECT * FROM admin_reports WHERE id = ?', { reportId }, function(report)
        if not report or report.status == 'closed' then return end

        local isAdmin = CanViewReports(src)
        if report.reporter_license ~= RSGCore.Functions.GetIdentifier(src, 'license') and not isAdmin then return end
        local senderType = isAdmin and 'admin' or 'player'

        MySQL.insert('INSERT INTO admin_report_messages (report_id, sender_type, sender_id, sender_name, message) VALUES (?, ?, ?, ?, ?)', {
            reportId, senderType, src, senderName, message,
        }, function(messageId)
            if not messageId then return end
            NotifyPlayer(src, locale('sv_report_reply_sent'), locale('sv_report_reply_sent_desc'), 'success')

            if senderType == 'admin' then
                local reporter = GetOnlineReporter(report)
                if reporter and reporter ~= src then
                    TriggerClientEvent('rsg-adminmenu:client:reportreplynotification', reporter, { reportId = reportId, adminName = senderName })
                end
                LogAdminAction('admin_action', 'low', src, locale('sv_log_replied_report', tostring(reportId)), nil, nil)
            else
                local payload = { id = reportId, reporter_name = senderName, report_type = 'response' }
                local assigned = tonumber(report.assigned_admin_id)
                if assigned and RSGCore.Functions.GetPlayer(assigned) and CanViewReports(assigned) then
                    TriggerClientEvent('rsg-adminmenu:client:newreportnotification', assigned, payload)
                else
                    NotifyStaff(payload)
                end
            end

            SendDiscordWebhook(Config.Reports.Webhooks.Main, {
                title = locale('sv_webhook_new_message', reportId),
                color = 3447003,
                fields = {
                    { name = locale('sv_webhook_field_sender'), value = senderName .. ' (' .. senderType .. ')', inline = false },
                    { name = locale('sv_webhook_field_report_id'), value = '#' .. reportId, inline = false },
                    { name = locale('sv_webhook_field_message'), value = message, inline = false },
                },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            })
        end)
    end)
end)

AddEventHandler('playerDropped', function()
    replyCooldowns[source] = nil
end)
