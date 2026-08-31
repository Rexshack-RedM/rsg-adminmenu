local RSGCore = exports['rsg-core']:GetCoreObject()

-- self-migrating: the persisted source of truth for "who is an admin and what
-- role do they hold" — ACE principals granted via AddPermission are session-only
-- (lost on disconnect), so this table is what makes a role assignment durable
MySQL.query([[
    CREATE TABLE IF NOT EXISTS `admin_roles` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `license` VARCHAR(100) DEFAULT NULL,
        `discord` VARCHAR(50) DEFAULT NULL,
        `name` VARCHAR(255) DEFAULT NULL,
        `role` VARCHAR(20) NOT NULL,
        `granted_by` VARCHAR(255) DEFAULT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])

-- re-sync ACE from the persisted table on every connect (carries a DB-stored
-- role across sessions without ever touching server.cfg) — and the other way
-- around: an admin granted straight through server.cfg (e.g. the bootstrap
-- owner/'god' account) has no admin_roles row yet, so without this they'd
-- never appear in the Admins page at all. Only backfills when no row exists
-- yet, so it never silently overwrites a role someone changed via the panel.
local function SyncAdminRole(Player)
    local citizenid = Player.PlayerData.citizenid
    local src = Player.PlayerData.source
    MySQL.single('SELECT role FROM admin_roles WHERE citizenid = ?', { citizenid }, function(row)
        if row and row.role then
            RSGCore.Functions.AddPermission(src, row.role)
            return
        end
        for _, level in ipairs(RSGCore.Config.Server.Permissions) do
            if RSGCore.Functions.HasPermission(src, level) then
                local name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
                local discord = RSGCore.Functions.GetIdentifier(src, 'discord')
                MySQL.insert([[
                    INSERT INTO admin_roles (citizenid, license, discord, name, role, granted_by) VALUES (?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE role = role
                ]], { citizenid, nil, discord, name, level, 'server.cfg' })
                break
            end
        end
    end)
end

AddEventHandler('RSGCore:Server:PlayerLoaded', SyncAdminRole)

-- PlayerLoaded only fires on connect, so anyone already online when this
-- resource (re)starts needs the same backfill check run once at startup
CreateThread(function()
    Wait(2000)
    for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
        local Player = RSGCore.Functions.GetPlayer(playerId)
        if Player then SyncAdminRole(Player) end
    end
end)

-- friendly display names for the raw ACE role strings — global (not local) so
-- server.lua's getplayerinfo can reuse it too. Falls back to a capitalized
-- version of the raw string for any role added later that isn't listed here.
RoleLabels = {
    god = 'Owner',
    headadmin = 'Head Admin',
    developer = 'Developer',
    admin = 'Admin',
    mod = 'Moderator',
    helper = 'Helper',
}

function LabelForRole(role)
    if not role or role == '' then return 'User' end
    return RoleLabels[role] or (role:sub(1, 1):upper() .. role:sub(2))
end

-- ordered role list this server actually has configured — first entry is
-- treated as the highest level, matching GetPlayerRole's first-match-wins scan
local function GetRoleLevels()
    local levels = {}
    local count = #RSGCore.Config.Server.Permissions
    for i, role in ipairs(RSGCore.Config.Server.Permissions) do
        levels[role] = count - i + 1
    end
    return levels
end

local function GetRoleLevel(role)
    return GetRoleLevels()[role] or 0
end

-- shared path for every role change in the panel (the Admins page's "Change
-- Role"/"Add Admin" and PlayerManageModal's "Set Permission" both call this)
-- so the persisted table and live ACE state can never drift apart
function SetAdminRole(targetCitizenid, targetSrc, role, adminName, adminDiscord, targetName)
    if not GetRoleLevels()[role] then return false end

    if targetSrc then
        for _, lvl in ipairs(RSGCore.Config.Server.Permissions) do
            RSGCore.Functions.RemovePermission(targetSrc, lvl)
        end
        RSGCore.Functions.AddPermission(targetSrc, role)
    end

    MySQL.insert([[
        INSERT INTO admin_roles (citizenid, license, discord, name, role, granted_by) VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE role = ?, granted_by = ?, name = ?
    ]], {
        targetCitizenid, nil, adminDiscord, targetName, role, adminName,
        role, adminName, targetName,
    })
    return true
end

function RemoveAdminRole(targetCitizenid, targetSrc)
    if targetSrc then
        for _, lvl in ipairs(RSGCore.Config.Server.Permissions) do
            RSGCore.Functions.RemovePermission(targetSrc, lvl)
        end
    end
    MySQL.update('DELETE FROM admin_roles WHERE citizenid = ?', { targetCitizenid })
end

-----------------------------------------------------------------------
-- role hierarchy config (drives the banner + the role dropdowns)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getroleconfig', function(source, cb)
    local levels = GetRoleLevels()
    local roles = {}
    for _, role in ipairs(RSGCore.Config.Server.Permissions) do
        roles[#roles + 1] = { role = role, level = levels[role], label = LabelForRole(role) }
    end
    cb(roles)
end)

-----------------------------------------------------------------------
-- roster
-----------------------------------------------------------------------
local function Placeholders(n)
    local parts = {}
    for i = 1, n do parts[i] = '?' end
    return table.concat(parts, ', ')
end

-- batched: 3 queries total regardless of staff headcount, not 1 + 2 per
-- admin. The old version fired a `player_playtime` lookup and an
-- `admin_reports` count separately for every single row, which is fine with
-- a handful of staff but turns into a real N+1 query storm on a server with
-- a large admin team, on every single Admins page load/refresh.
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getadmins', function(source, cb)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['playerinfo']) or IsPlayerAceAllowed(src, 'god')) then
        cb(nil)
        return
    end

    MySQL.query('SELECT * FROM admin_roles ORDER BY created_at ASC', {}, function(rows)
        rows = rows or {}
        if #rows == 0 then
            cb({})
            return
        end

        local citizenids, names = {}, {}
        for _, row in ipairs(rows) do
            citizenids[#citizenids + 1] = row.citizenid
            names[#names + 1] = row.name
        end

        MySQL.query('SELECT citizenid, last_seen FROM player_playtime WHERE citizenid IN (' .. Placeholders(#citizenids) .. ')', citizenids, function(ptRows)
            local lastSeenByCitizen = {}
            for _, r in ipairs(ptRows or {}) do
                lastSeenByCitizen[r.citizenid] = r.last_seen
            end

            -- assigned_admin_id is only a live server-id snapshot, not reliably
            -- joinable once that admin has disconnected, so match by stored name
            local reportParams = { 'resolved' }
            for _, n in ipairs(names) do reportParams[#reportParams + 1] = n end
            MySQL.query(
                'SELECT assigned_admin_name, COUNT(*) as total FROM admin_reports WHERE status = ? AND assigned_admin_name IN (' .. Placeholders(#names) .. ') GROUP BY assigned_admin_name',
                reportParams,
                function(reportRows)
                    local resolvedCountByName = {}
                    for _, r in ipairs(reportRows or {}) do
                        resolvedCountByName[r.assigned_admin_name] = r.total
                    end

                    local result = {}
                    for _, row in ipairs(rows) do
                        local onlinePlayer = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)
                        local discordId, discordName, discordAvatarUrl = nil, nil, nil
                        if onlinePlayer then
                            discordId, discordName, discordAvatarUrl = GetCachedDiscordIdentity(onlinePlayer.PlayerData.source)
                        end
                        result[#result + 1] = {
                            citizenid = row.citizenid,
                            name = row.name,
                            role = row.role,
                            roleLabel = LabelForRole(row.role),
                            grantedBy = row.granted_by,
                            createdAt = row.created_at,
                            serverId = onlinePlayer and onlinePlayer.PlayerData.source or nil,
                            online = onlinePlayer ~= nil,
                            steamHex = onlinePlayer and RSGCore.Functions.GetIdentifier(onlinePlayer.PlayerData.source, 'steam') or nil,
                            lastSeen = lastSeenByCitizen[row.citizenid],
                            discordId = discordId,
                            discordName = discordName,
                            discordAvatarUrl = discordAvatarUrl,
                            reportsResolved = resolvedCountByName[row.name] or 0,
                        }
                    end
                    cb(result)
                end
            )
        end)
    end)
end)

-----------------------------------------------------------------------
-- add admin — only works for a currently-online player (there's no stored
-- steam-hex column on `players` to resolve an offline identifier against)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:addadmin', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['setpermission']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false, message = 'Not allowed' })
        return
    end

    local steamHex = data.steamHex
    local targetSrc = nil
    for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
        if RSGCore.Functions.GetIdentifier(playerId, 'steam') == steamHex then
            targetSrc = playerId
            break
        end
    end

    if not targetSrc then
        cb({ success = false, message = 'Player must be online to be added as an admin' })
        return
    end

    local admin = RSGCore.Functions.GetPlayer(src)
    local adminName = admin.PlayerData.charinfo.firstname .. ' ' .. admin.PlayerData.charinfo.lastname
    local target = RSGCore.Functions.GetPlayer(targetSrc)
    local targetName = target.PlayerData.charinfo.firstname .. ' ' .. target.PlayerData.charinfo.lastname
    local targetDiscord = RSGCore.Functions.GetIdentifier(targetSrc, 'discord')

    if SetAdminRole(target.PlayerData.citizenid, targetSrc, data.role, adminName, targetDiscord, targetName) then
        LogAdminAction('admin_action', 'high', src, 'Granted \'' .. LabelForRole(data.role) .. '\' role to ' .. targetName, 'Target: ' .. targetName, targetName, targetSrc)
        cb({ success = true })
    else
        cb({ success = false, message = 'Invalid role' })
    end
end)

-----------------------------------------------------------------------
-- change an existing admin's role
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:changeadminrole', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['setpermission']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false })
        return
    end

    local admin = RSGCore.Functions.GetPlayer(src)
    local adminName = admin.PlayerData.charinfo.firstname .. ' ' .. admin.PlayerData.charinfo.lastname
    local onlinePlayer = RSGCore.Functions.GetPlayerByCitizenId(data.citizenid)

    if SetAdminRole(data.citizenid, onlinePlayer and onlinePlayer.PlayerData.source or nil, data.role, adminName, nil, data.name) then
        LogAdminAction('admin_action', 'high', src, 'Changed ' .. (data.name or data.citizenid) .. '\'s role to \'' .. LabelForRole(data.role) .. '\'', nil, data.name, onlinePlayer and onlinePlayer.PlayerData.source or nil)
        cb({ success = true })
    else
        cb({ success = false })
    end
end)

-----------------------------------------------------------------------
-- remove admin access entirely
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:removeadmin', function(source, cb, data)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['setpermission']) or IsPlayerAceAllowed(src, 'god')) then
        cb({ success = false })
        return
    end

    local onlinePlayer = RSGCore.Functions.GetPlayerByCitizenId(data.citizenid)
    RemoveAdminRole(data.citizenid, onlinePlayer and onlinePlayer.PlayerData.source or nil)
    LogAdminAction('admin_action', 'high', src, 'Removed admin access from ' .. (data.name or data.citizenid), nil, data.name, onlinePlayer and onlinePlayer.PlayerData.source or nil)
    cb({ success = true })
end)
