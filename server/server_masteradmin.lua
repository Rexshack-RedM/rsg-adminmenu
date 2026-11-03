local RSGCore = exports['rsg-core']:GetCoreObject()

local CONFIG_FILE = 'server/sv_config.lua'

local function CanUseMasterAdmin(src)
    return HasAdminPermission(src, 'serversettings')
end

-----------------------------------------------------------------------
-- persisted settings (webhook URLs) — a key/value store so edits made in
-- Master Actions survive a restart. On start each stored key is written
-- back into the live Config table.
-----------------------------------------------------------------------
-- maps a stored setting key to where it lives in the global Config table
local settingsConfigPath = {
    webhook_adminlogs = { 'Webhooks', 'AdminLogs' },
    webhook_playermanagement = { 'Webhooks', 'PlayerManagement' },
    webhook_worldsettings = { 'Webhooks', 'WorldSettings' },
    webhook_reports = { 'Reports', 'Webhooks', 'Main' },
}

local function GetSetting(key)
    local node = Config
    for _, part in ipairs(settingsConfigPath[key]) do
        node = node and node[part]
    end
    return type(node) == 'string' and node or ''
end

local function ApplySetting(key, value)
    local path = settingsConfigPath[key]
    if not path then return end
    local node = Config
    for i = 1, #path - 1 do
        node = node[path[i]]
        if not node then return end
    end
    node[path[#path]] = value
end

-- also writes the value into server/sv_config.lua so it stays the default on a
-- fresh database (SaveResourceFile can only write inside this resource)
local function WriteConfigFile(key, value)
    local path = settingsConfigPath[key]
    if not path then return false end

    local resource = GetCurrentResourceName()
    local content = LoadResourceFile(resource, CONFIG_FILE)
    if not content then return false end

    -- value is already validated as a plain URL (no quotes/newlines); % must be escaped for gsub
    local replacement = tostring(value):gsub('%%', '%%%%')
    local pattern = '(' .. path[#path] .. '%s*=%s*")[^"]*(")'
    local newContent, count = content:gsub(pattern, '%1' .. replacement .. '%2', 1)
    if count == 0 then return false end

    return SaveResourceFile(resource, CONFIG_FILE, newContent, -1)
end

-- accepts '' (disabled) or a Discord webhook URL
local function IsValidWebhook(url)
    if url == '' then return true end
    return #url <= 300
        and (url:match('^https://discord%.com/api/webhooks/[%w/_%-]+$') or url:match('^https://discordapp%.com/api/webhooks/[%w/_%-]+$')
            or url:match('^https://ptb%.discord%.com/api/webhooks/[%w/_%-]+$') or url:match('^https://canary%.discord%.com/api/webhooks/[%w/_%-]+$')) ~= nil
end

local function BuildItemData(row)
    return {
        name = row.name,
        label = row.label,
        weight = tonumber(row.weight) or 0,
        type = row.type,
        image = row.image,
        unique = false,
        useable = true,
        shouldClose = true,
        description = row.description,
    }
end

OnDatabaseReady(function()
    MySQL.query('SELECT * FROM adminmenu_settings', {}, function(rows)
        for _, row in ipairs(rows or {}) do
            ApplySetting(row.setting_key, row.setting_value)
        end
    end)

    -- custom items added from older versions of the panel are re-registered
    -- through rsg-core's item API on every start (never touches items.lua)
    MySQL.query('SELECT * FROM adminmenu_custom_items', {}, function(rows)
        for _, row in ipairs(rows or {}) do
            local item = BuildItemData(row)
            local ok, reason = RSGCore.Functions.AddItem(item.name, item)
            if not ok and reason == 'item_exists' then
                RSGCore.Functions.UpdateItem(item.name, item)
            end
        end
    end)
end)

-----------------------------------------------------------------------
-- webhook settings
-----------------------------------------------------------------------
local webhookFields = {
    { key = 'webhook_adminlogs', field = 'adminLogs', label = 'sv_webhook_label_adminlogs' },
    { key = 'webhook_playermanagement', field = 'playerManagement', label = 'sv_webhook_label_playermanagement' },
    { key = 'webhook_worldsettings', field = 'worldSettings', label = 'sv_webhook_label_worldsettings' },
    { key = 'webhook_reports', field = 'reports', label = 'sv_webhook_label_reports' },
}

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getwebhooksettings', function(source, cb)
    if not CanUseMasterAdmin(source) then return cb({}) end
    local result = {}
    for _, f in ipairs(webhookFields) do result[f.field] = GetSetting(f.key) end
    cb(result)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:savewebhooksettings', function(source, cb, data)
    local src = source
    if not CanUseMasterAdmin(src) or type(data) ~= 'table' then return cb({ success = false }) end

    local values = {}
    for _, f in ipairs(webhookFields) do
        local value = type(data[f.field]) == 'string' and data[f.field]:gsub('^%s+', ''):gsub('%s+$', '') or ''
        if not IsValidWebhook(value) then
            return cb({ success = false, message = locale('sv_invalid_webhook', locale(f.label)) })
        end
        values[f.key] = value
    end

    local changeLines = {}
    for _, f in ipairs(webhookFields) do
        local old, value = GetSetting(f.key), values[f.key]
        if old ~= value then
            -- only the tail of each URL goes in the log so the full secret never lands in Discord/DB logs
            local function mask(url) return url ~= '' and ('...' .. url:sub(-6)) or locale('sv_empty') end
            changeLines[#changeLines + 1] = locale('sv_log_webhook_change', locale(f.label), mask(old), mask(value))
            MySQL.insert('INSERT INTO adminmenu_settings (setting_key, setting_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)', { f.key, value })
            ApplySetting(f.key, value)
            WriteConfigFile(f.key, value)
        end
    end

    if #changeLines > 0 then
        LogAdminAction('admin_action', 'high', src, locale('sv_log_updated_webhook_settings'), table.concat(changeLines, '\n\n'), nil)
    end
    cb({ success = true })
end)
