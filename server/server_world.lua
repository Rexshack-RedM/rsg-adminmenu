local RSGCore = exports['rsg-core']:GetCoreObject()

local TELEPORT_CATEGORIES = { towns = true, gangcamps = true, nature = true, shops = true, special = true }
local ENTITY_TYPES = { ped = true, animal = true, horse = true, wagon = true, prop = true }

local function CanUseWorldTools(src)
    return HasAdminPermission(src, 'worldtools')
end

-- returns x, y, z (and heading) as floats, or nil if any coord is missing / not finite
local function ReadCoords(data)
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if not x or not y or not z then return nil end
    for _, v in ipairs({ x, y, z }) do
        if v ~= v or math.abs(v) > 100000 then return nil end
    end
    return x, y, z, (tonumber(data.heading) or 0.0) % 360
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getteleportlocations', function(source, cb)
    if not HasAdminPermission(source, 'playerinfo') then return cb({}) end
    MySQL.query('SELECT * FROM adminmenu_teleports ORDER BY name ASC', {}, function(rows)
        cb(rows or {})
    end)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:addteleportlocation', function(source, cb, data)
    local src = source
    data = type(data) == 'table' and data or {}
    local name = SanitizeText(data.name, 100)
    local x, y, z, heading = ReadCoords(data)
    if not CanUseWorldTools(src) or not name or not x then return cb({ success = false }) end
    local category = TELEPORT_CATEGORIES[data.category] and data.category or 'special'

    MySQL.insert('INSERT INTO adminmenu_teleports (name, category, description, x, y, z, heading, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        name, category, SanitizeText(data.description, 255), x, y, z, heading, AdminDisplayName(src),
    }, function(insertId)
        if insertId then
            LogAdminAction('admin_action', 'low', src, locale('sv_log_added_teleport', name), nil, nil)
        end
        cb({ success = insertId ~= nil, id = insertId })
    end)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:deleteteleportlocation', function(source, cb, data)
    local id = tonumber(type(data) == 'table' and data.id)
    if not CanUseWorldTools(source) or not id then return cb({ success = false }) end
    MySQL.update('DELETE FROM adminmenu_teleports WHERE id = ?', { id }, function(affected)
        cb({ success = (affected or 0) > 0 })
    end)
end)

-----------------------------------------------------------------------
-- persistent map blips (shown to staff only)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getblips', function(source, cb)
    if not HasAdminPermission(source, 'playerinfo') then return cb({}) end
    MySQL.query('SELECT * FROM adminmenu_blips ORDER BY name ASC', {}, function(rows)
        cb(rows or {})
    end)
end)

local function SendBlips(targets)
    MySQL.query('SELECT * FROM adminmenu_blips', {}, function(rows)
        for _, playerId in ipairs(targets) do
            TriggerClientEvent('rsg-adminmenu:client:syncblips', playerId, rows or {})
        end
    end)
end

local function BroadcastBlips()
    local staff = {}
    for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
        if HasAdminPermission(playerId, 'adminmenu') then staff[#staff + 1] = playerId end
    end
    if #staff > 0 then SendBlips(staff) end
end

-- returns the validated blip fields, or nil
local function ReadBlip(data)
    local name = SanitizeText(data.name, 100)
    local sprite = SanitizeText(data.sprite, 50)
    local x, y, z = ReadCoords(data)
    if not name or not sprite or not x then return nil end
    local scale = math.max(0.1, math.min(5.0, tonumber(data.scale) or 1.0))
    return { name, sprite, x, y, z, scale }
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:addblip', function(source, cb, data)
    local src = source
    local blip = type(data) == 'table' and ReadBlip(data)
    if not CanUseWorldTools(src) or not blip then return cb({ success = false }) end
    blip[#blip + 1] = AdminDisplayName(src)

    MySQL.insert('INSERT INTO adminmenu_blips (name, sprite, x, y, z, scale, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)', blip, function(insertId)
        if insertId then
            LogAdminAction('admin_action', 'low', src, locale('sv_log_added_blip', blip[1]), nil, nil)
            BroadcastBlips()
        end
        cb({ success = insertId ~= nil })
    end)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:updateblip', function(source, cb, data)
    local blip = type(data) == 'table' and ReadBlip(data)
    local id = blip and tonumber(data.id)
    if not CanUseWorldTools(source) or not id then return cb({ success = false }) end
    blip[#blip + 1] = id

    MySQL.update('UPDATE adminmenu_blips SET name = ?, sprite = ?, x = ?, y = ?, z = ?, scale = ? WHERE id = ?', blip, function(affected)
        BroadcastBlips()
        cb({ success = (affected or 0) > 0 })
    end)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:deleteblip', function(source, cb, data)
    local id = tonumber(type(data) == 'table' and data.id)
    if not CanUseWorldTools(source) or not id then return cb({ success = false }) end
    MySQL.update('DELETE FROM adminmenu_blips WHERE id = ?', { id }, function(affected)
        BroadcastBlips()
        cb({ success = (affected or 0) > 0 })
    end)
end)

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    if HasAdminPermission(src, 'adminmenu') then SendBlips({ src }) end
end)

-----------------------------------------------------------------------
-- spawner / clear area (the entity is created on the admin's own client)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:spawnentity', function(source, cb, data)
    local src = source
    if not CanUseWorldTools(src) then return cb({ success = false }) end
    data = type(data) == 'table' and data or {}
    local hash = SanitizeText(data.hash, 100)
    hash = hash and hash:gsub('%s+', '') or nil
    if not hash or hash == '' then
        return cb({ success = false, message = locale('sv_hash_name_required') })
    end
    if not ENTITY_TYPES[data.entityType] then return cb({ success = false }) end

    TriggerClientEvent('rsg-adminmenu:client:spawnentity', src, data.entityType, hash)
    LogAdminAction('admin_action', 'low', src, locale('sv_log_spawned_entity'), data.entityType .. ': ' .. hash, nil)
    cb({ success = true })
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:cleararea', function(source, cb, data)
    local src = source
    if not CanUseWorldTools(src) then
        return cb({ success = false, message = locale('sv_no_permission') })
    end
    local radius = math.max(5.0, math.min(100.0, tonumber(type(data) == 'table' and data.radius) or 25.0))
    TriggerClientEvent('rsg-adminmenu:client:cleararea', src, radius)
    LogAdminAction('admin_action', 'low', src, locale('sv_log_cleared_area'), locale('sv_log_radius', ('%.0f'):format(radius)), nil)
    cb({ success = true, radius = radius })
end)
