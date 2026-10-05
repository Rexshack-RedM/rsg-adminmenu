local RSGCore = exports['rsg-core']:GetCoreObject()

-- self-migrating: don't depend on the SQL file having been run by hand
MySQL.query([[
    CREATE TABLE IF NOT EXISTS `admin_logs` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `category` VARCHAR(20) NOT NULL,
        `severity` VARCHAR(10) NOT NULL DEFAULT 'low',
        `admin_citizenid` VARCHAR(50) DEFAULT NULL,
        `admin_name` VARCHAR(255) DEFAULT NULL,
        `action` VARCHAR(255) NOT NULL,
        `details` VARCHAR(500) DEFAULT NULL,
        `target_name` VARCHAR(255) DEFAULT NULL,
        `ip` VARCHAR(50) DEFAULT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `category` (`category`),
        KEY `admin_citizenid` (`admin_citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])

-- category -> which Config.Webhooks entry it posts to. 'system' (resource
-- start/stop) is deliberately unmapped: those never have an acting admin, so
-- LogAdminAction already skips Discord for them entirely
local categoryWebhookKey = {
    admin_action = 'AdminLogs',
    security = 'AdminLogs',
    player_action = 'PlayerManagement',
    economy = 'PlayerManagement',
    server_event = 'WorldSettings',
}
local severityColor = { low = 3447003, medium = 16776960, high = 16711680 }

-- posts a single, consistently-formatted Discord embed straight to a raw
-- webhook URL: who did it (author), what happened (title), the actual
-- change/details in a fenced code block, an optional target, and a real
-- Discord timestamp (renders auto-localized to the viewer, with the little
-- clock icon). Used by both the automatic per-category logging below and the
-- manual "Send to Discord" button on a single Logs entry — one code path, so
-- both actually work instead of the button depending on a separate,
-- unverified rsg-essentials webhook pipeline.
function SendDiscordEmbed(url, title, adminName, body, color, targetName)
    if not url or url == '' or url == 'YOUR_WEBHOOK_URL_HERE' then return end

    local fields = {}
    if targetName then
        fields[#fields + 1] = { name = locale('sv_webhook_target'), value = tostring(targetName), inline = true }
    end

    PerformHttpRequest(url, function() end, 'POST', json.encode({
        embeds = { {
            title = title,
            author = { name = adminName or locale('sv_system') },
            description = '```\n' .. (body or locale('sv_no_additional_details')) .. '\n```',
            color = color or 3447003,
            fields = fields,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            footer = { text = locale('sv_webhook_footer') },
        } },
    }), { ['Content-Type'] = 'application/json' })
end

-- global (not local) — this is the single instrumentation point every
-- mutating admin action across this resource calls into. `src` may be nil
-- for system-level events (resource start/stop) that have no acting admin.
-- `targetSrc` is optional — pass it whenever the target is a live connected
-- player so their Discord name can be resolved too; omit it when only a
-- name string is available (offline target, no single player involved, etc).
function LogAdminAction(category, severity, src, action, details, targetName, targetSrc)
    local adminCitizenid, adminName, ip = nil, nil, nil
    if src then
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player then
            adminCitizenid = Player.PlayerData.citizenid
        end
        adminName = AdminDisplayName(src)
        ip = RSGCore.Functions.GetIdentifier(src, 'ip')
    end

    if targetSrc then
        local _, targetDiscordName = GetCachedDiscordIdentity(targetSrc)
        if targetDiscordName then targetName = targetDiscordName end
    end

    MySQL.insert('INSERT INTO admin_logs (category, severity, admin_citizenid, admin_name, action, details, target_name, ip) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        category, severity, adminCitizenid, adminName, action, details, targetName, ip,
    })

    -- system events (src == nil, e.g. resource start/stop) aren't "something
    -- an admin did", so they only go to the DB above, never to Discord
    if src and categoryWebhookKey[category] then
        local url = Config.Webhooks[categoryWebhookKey[category]]
        SendDiscordEmbed(url, action, adminName, details, severityColor[severity], targetName)
    end
end

-----------------------------------------------------------------------
-- system-level logs — resource lifecycle, no acting admin
-----------------------------------------------------------------------
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end
    LogAdminAction('system', 'low', nil, locale('sv_log_started_resource', resourceName), locale('sv_log_resource_action', resourceName, 'start'), nil)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end
    LogAdminAction('system', 'low', nil, locale('sv_log_stopped_resource', resourceName), locale('sv_log_resource_action', resourceName, 'stop'), nil)
end)

-----------------------------------------------------------------------
-- list / filter / paginate
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getlogs', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['playerinfo']) or IsPlayerAceAllowed(src, 'god')) then
        cb(nil)
        return
    end

    data = data or {}
    local where = {}
    local params = {}

    if data.category and data.category ~= 'all' then
        where[#where + 1] = 'category = ?'
        params[#params + 1] = data.category
    end
    if data.adminCitizenid then
        where[#where + 1] = 'admin_citizenid = ?'
        params[#params + 1] = data.adminCitizenid
    end
    if data.search and data.search ~= '' then
        where[#where + 1] = '(action LIKE ? OR details LIKE ? OR admin_name LIKE ?)'
        local like = '%' .. data.search .. '%'
        params[#params + 1] = like
        params[#params + 1] = like
        params[#params + 1] = like
    end

    local whereSql = #where > 0 and ('WHERE ' .. table.concat(where, ' AND ')) or ''
    local page = tonumber(data.page) or 1
    local perPage = 20
    local offset = (page - 1) * perPage

    MySQL.query('SELECT COUNT(*) as total FROM admin_logs ' .. whereSql, params, function(countResult)
        local total = (countResult and countResult[1] and countResult[1].total) or 0

        local pageParams = {}
        for _, p in ipairs(params) do pageParams[#pageParams + 1] = p end
        pageParams[#pageParams + 1] = perPage
        pageParams[#pageParams + 1] = offset

        MySQL.query('SELECT * FROM admin_logs ' .. whereSql .. ' ORDER BY created_at DESC LIMIT ? OFFSET ?', pageParams, function(rows)
            MySQL.query([[
                SELECT category, COUNT(*) as count FROM admin_logs GROUP BY category
            ]], {}, function(categoryCounts)
                local counts = { admin_action = 0, economy = 0, player_action = 0, security = 0, server_event = 0, system = 0 }
                for _, row in ipairs(categoryCounts or {}) do
                    counts[row.category] = row.count
                end
                cb({ logs = rows or {}, total = total, page = page, perPage = perPage, counts = counts })
            end)
        end)
    end)
end)

-----------------------------------------------------------------------
-- forward a single log entry to Discord on demand — goes straight to the
-- same per-category webhook (Config.Webhooks) the automatic logging uses,
-- not the old rsg-log:server:CreateLog -> rsg-essentials pipeline (that
-- depends on a webhook configured in a different resource entirely, which
-- this panel has no visibility into and can't guarantee is even set up)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:sendlogtodiscord', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['playerinfo']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false })
        return
    end

    MySQL.single('SELECT * FROM admin_logs WHERE id = ?', { data.logId }, function(log)
        if not log then
            cb({ success = false, reason = 'log_not_found' })
            return
        end

        -- a manually-clicked send should still go somewhere even for a category
        -- with no dedicated mapping (e.g. 'system') — fall back to Admin Logs
        local webhookKey = categoryWebhookKey[log.category] or 'AdminLogs'
        local url = Config.Webhooks[webhookKey]
        if not url or url == '' or url == 'YOUR_WEBHOOK_URL_HERE' then
            cb({ success = false, reason = 'webhook_not_configured' })
            return
        end

        SendDiscordEmbed(url, log.action, log.admin_name, log.details, severityColor[log.severity], log.target_name)
        cb({ success = true })
    end)
end)
