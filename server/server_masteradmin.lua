local RSGCore = exports['rsg-core']:GetCoreObject()

local function CanUseMasterAdmin(src)
    return HasAdminPermission(src, 'serversettings')
end

local CONFIG_FILE = 'server/sv_config.lua'

-----------------------------------------------------------------------
-- persisted settings (webhook URLs, etc.) — a generic key/value store so
-- edits made in the Master Admin section survive a resource restart. On
-- start, each stored key is written back into the live Config table so
-- every other file that reads Config.* picks up the override transparently.
-----------------------------------------------------------------------
MySQL.query([[
    CREATE TABLE IF NOT EXISTS `adminmenu_settings` (
        `setting_key` VARCHAR(64) NOT NULL,
        `setting_value` TEXT,
        PRIMARY KEY (`setting_key`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])

MySQL.query([[
    CREATE TABLE IF NOT EXISTS `adminmenu_custom_items` (
        `name` VARCHAR(64) NOT NULL,
        `label` VARCHAR(100) NOT NULL,
        `description` VARCHAR(255) DEFAULT NULL,
        `weight` INT(11) NOT NULL DEFAULT 0,
        `type` VARCHAR(20) NOT NULL DEFAULT 'item',
        `image` VARCHAR(150) NOT NULL,
        `created_by` VARCHAR(255) DEFAULT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])

-- maps a stored setting key to where it lives in the global Config table
local settingsConfigPath = {
    webhook_adminlogs = { 'Webhooks', 'AdminLogs' },
    webhook_playermanagement = { 'Webhooks', 'PlayerManagement' },
    webhook_worldsettings = { 'Webhooks', 'WorldSettings' },
    webhook_reports = { 'Reports', 'Webhooks', 'Main' },
}

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

-- writes a setting straight into server/sv_config.lua's source text (not just the live
-- Config table + DB) so it's visible in the file and stays the default on a
-- fresh migration. Only safe because config.lua lives inside THIS resource's
-- own folder — SaveResourceFile can't write outside the calling resource,
-- unlike e.g. rsg-core's or rsg-inventory's files.
local function WriteConfigFile(key, value)
    local path = settingsConfigPath[key]
    if not path then return false end
    local fieldName = path[#path]

    local content = LoadResourceFile(GetCurrentResourceName(), CONFIG_FILE)
    if not content then return false end

    -- keep the value a valid single-line Lua string literal
    local literal = tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', ' ')
    -- gsub's replacement string treats % specially, so escape it separately
    local replacement = literal:gsub('%%', '%%%%')

    local pattern = '(' .. fieldName .. '%s*=%s*")[^"]*(")'
    local newContent, count = content:gsub(pattern, '%1' .. replacement .. '%2', 1)
    if count == 0 then return false end

    SaveResourceFile(GetCurrentResourceName(), CONFIG_FILE, newContent, -1)
    return true
end

MySQL.query('SELECT * FROM adminmenu_settings', {}, function(rows)
    for _, row in ipairs(rows or {}) do
        ApplySetting(row.setting_key, row.setting_value)
    end
end)

local function BuildItemData(name, label, weight, itemType, image, description)
    return {
        name = name,
        label = label,
        weight = weight,
        type = itemType,
        image = image,
        unique = false,
        useable = true,
        shouldClose = true,
        description = description,
    }
end

-- registers (or re-registers) an item through rsg-core's own AddItem/UpdateItem
-- exports — NOT a direct RSGCore.Shared.Items[name] = ... write. GetCoreObject()
-- hands back a disconnected snapshot of that table, so a plain field write on
-- it only mutates our own local copy and is invisible to rsg-core and every
-- other resource (that's why custom items weren't showing up anywhere). These
-- exports run inside rsg-core's own resource and correctly sync everywhere,
-- including a live client push (RSGCore:Client:OnSharedUpdate).
local function RegisterItem(itemData)
    local ok, reason = RSGCore.Functions.AddItem(itemData.name, itemData)
    if not ok and reason == 'item_exists' then
        ok, reason = RSGCore.Functions.UpdateItem(itemData.name, itemData)
    end
    return ok, reason
end

-- replays every stored custom item through rsg-core's real item API on every
-- start — this resource never touches rsg-core's own items.lua file
MySQL.query('SELECT * FROM adminmenu_custom_items', {}, function(rows)
    for _, row in ipairs(rows or {}) do
        RegisterItem(BuildItemData(row.name, row.label, tonumber(row.weight) or 0, row.type, row.image, row.description))
    end
end)

-----------------------------------------------------------------------
-- webhook settings
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getwebhooksettings', function(source, cb)
    local src = source
    if not CanUseMasterAdmin(src) then
        cb({})
        return
    end
    cb({
        adminLogs = Config.Webhooks.AdminLogs or '',
        playerManagement = Config.Webhooks.PlayerManagement or '',
        worldSettings = Config.Webhooks.WorldSettings or '',
        reports = Config.Reports.Webhooks.Main or '',
    })
end)

local webhookFieldLabels = {
    webhook_adminlogs = locale('sv_webhook_label_adminlogs'),
    webhook_playermanagement = locale('sv_webhook_label_playermanagement'),
    webhook_worldsettings = locale('sv_webhook_label_worldsettings'),
    webhook_reports = locale('sv_webhook_label_reports'),
}

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:savewebhooksettings', function(source, cb, data)
    local src = source
    if not CanUseMasterAdmin(src) then
        cb({ success = false })
        return
    end
    if type(data) ~= 'table' then
        cb({ success = false })
        return
    end
    -- only accept empty values or real Discord webhook URLs
    local function webhook(value)
        value = CleanText(value, 300) or ''
        if value ~= '' and not value:match('^https://discord%.com/api/webhooks/%d+/[%w_%-]+$')
            and not value:match('^https://discordapp%.com/api/webhooks/%d+/[%w_%-]+$') then
            return nil
        end
        return value
    end
    local map = {
        webhook_adminlogs = webhook(data.adminLogs),
        webhook_playermanagement = webhook(data.playerManagement),
        webhook_worldsettings = webhook(data.worldSettings),
        webhook_reports = webhook(data.reports),
    }
    for _, v in pairs(map) do
        if v == nil then
            cb({ success = false, message = locale('sv_invalid_input') })
            return
        end
    end
    -- capture the old value of each field before anything gets overwritten,
    -- so the change log below can show a real from -> to, not just "updated"
    local oldValues = {
        webhook_adminlogs = Config.Webhooks.AdminLogs or '',
        webhook_playermanagement = Config.Webhooks.PlayerManagement or '',
        webhook_worldsettings = Config.Webhooks.WorldSettings or '',
        webhook_reports = Config.Reports.Webhooks.Main or '',
    }

    local changeLines = {}
    for key, value in pairs(map) do
        local old = oldValues[key] or ''
        if old ~= value then
            changeLines[#changeLines + 1] = locale('sv_log_webhook_change', webhookFieldLabels[key], (old ~= '' and old or locale('sv_empty')),
                (value ~= '' and value or locale('sv_empty')))
        end
        MySQL.query(
            'INSERT INTO adminmenu_settings (setting_key, setting_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE setting_value = ?',
            { key, value, value }
        )
        ApplySetting(key, value)
        WriteConfigFile(key, value)
    end

    if #changeLines > 0 then
        LogAdminAction('admin_action', 'high', src, locale('sv_log_updated_webhook_settings'), table.concat(changeLines, '\n\n'), nil)
    end
    cb({ success = true })
end)

-----------------------------------------------------------------------
-- custom items — registers item data (name/label/weight/type/description/
-- image reference) live via rsg-core's own AddItem/UpdateItem/RemoveItem
-- exports, no restart needed. It cannot place the actual PNG file inside the
-- inventory resource's own
-- images folder (FXServer resources can't write outside their own folder) —
-- the image file itself still has to be copied there by hand.
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getcustomitems', function(source, cb)
    local src = source
    if not CanUseMasterAdmin(src) then
        cb({})
        return
    end
    MySQL.query('SELECT * FROM adminmenu_custom_items ORDER BY name ASC', {}, function(rows)
        cb(rows or {})
    end)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:addcustomitem', function(source, cb, data)
    local src = source
    if not CanUseMasterAdmin(src) then
        cb({ success = false })
        return
    end
    if type(data) ~= 'table' then return cb({ success = false }) end
    local name = CleanText(data.name, 64)
    name = name and (name:lower():gsub('[^%w_]', '_')) or nil
    local label = CleanText(data.label, 100)
    local image = CleanText(data.image, 150)
    local description = CleanText(data.description, 255)
    if not name or not label or not image or not image:match('^[%w_%-%.]+%.png$') then
        cb({ success = false, reason = 'invalid_input' })
        return
    end

    local adminName = AdminDisplayName(src)
    local weight = math.max(0, math.floor(tonumber(data.weight) or 0))
    local itemType = data.itemType == 'weapon' and 'weapon' or 'item'

    MySQL.insert([[
        INSERT INTO adminmenu_custom_items (name, label, description, weight, type, image, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), description = VALUES(description),
            weight = VALUES(weight), type = VALUES(type), image = VALUES(image)
    ]], { name, label, description, weight, itemType, image, adminName }, function()
        local ok, reason = RegisterItem(BuildItemData(name, label, weight, itemType, image, description))
        if not ok then
            cb({ success = false, reason = reason })
            return
        end
        LogAdminAction('admin_action', 'medium', src, locale('sv_log_added_custom_item', name), label, nil)
        cb({ success = true })
    end)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:deletecustomitem', function(source, cb, data)
    local src = source
    if not CanUseMasterAdmin(src) then
        cb({ success = false })
        return
    end
    local name = type(data) == 'table' and CleanText(data.name, 64) or nil
    if not name then return cb({ success = false }) end
    MySQL.update('DELETE FROM adminmenu_custom_items WHERE name = ?', { name }, function(affected)
        if affected and affected > 0 then
            RSGCore.Functions.RemoveItem(name)
            LogAdminAction('admin_action', 'medium', src, locale('sv_log_removed_custom_item', tostring(name)), nil, nil)
        end
        cb({ success = affected and affected > 0 })
    end)
end)
