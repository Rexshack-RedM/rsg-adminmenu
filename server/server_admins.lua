local RSGCore = exports['rsg-core']:GetCoreObject()

-- admin_roles is the persisted source of truth for "who is an admin and what
-- role do they hold" — ACE principals granted via AddPermission are session-only.
-- Re-sync ACE from it on every connect, and backfill a row for anyone granted
-- straight through server.cfg so they show up on the Admins page too. Only
-- backfills when no row exists, so it never overwrites a role changed in the panel.
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
                MySQL.insert([[
                    INSERT INTO admin_roles (citizenid, license, discord, name, role, granted_by) VALUES (?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE role = role
                ]], { citizenid, nil, RSGCore.Functions.GetIdentifier(src, 'discord'), name, level, 'server.cfg' })
                break
            end
        end
    end)
end

AddEventHandler('RSGCore:Server:PlayerLoaded', SyncAdminRole)

-- PlayerLoaded only fires on connect, so anyone already online when this
-- resource (re)starts gets the same sync once the tables are ready
OnDatabaseReady(function()
    for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
        local Player = RSGCore.Functions.GetPlayer(playerId)
        if Player then SyncAdminRole(Player) end
    end
end)

-- friendly display names for the raw ACE role strings; unknown roles fall back
-- to a capitalised version of the raw string
local RoleLabels = {
    god = locale('sv_role_owner'),
    headadmin = locale('sv_role_headadmin'),
    developer = locale('sv_role_developer'),
    admin = locale('sv_role_admin'),
    mod = locale('sv_role_moderator'),
    helper = locale('sv_role_helper'),
}

function LabelForRole(role)
    if not role or role == '' or role == 'user' then return locale('sv_role_user') end
    return RoleLabels[role] or (role:sub(1, 1):upper() .. role:sub(2))
end

-- first entry of RSGCore.Config.Server.Permissions is the highest level,
-- matching GetPlayerRole's first-match-wins scan; non-staff are level 0
function GetRoleLevel(role)
    local list = RSGCore.Config.Server.Permissions
    for i, r in ipairs(list) do
        if r == role then return #list - i + 1 end
    end
    return 0
end

local function ActorLevel(src)
    if IsPlayerAceAllowed(src, 'god') then return math.huge end
    return GetRoleLevel(GetPlayerRole(src))
end

-- global: true when src may use a punitive/protected action on target
-- (yourself, anyone below your rank, or anyone at all for the Owner)
function CanActOn(src, target)
    if src == target then return true end
    return GetRoleLevel(GetPlayerRole(target)) < ActorLevel(src)
end

-- shared path for every role change in the panel so the persisted table and
-- live ACE state never drift apart (no rank checks here: see ChangeAdminRole)
local function SetAdminRole(targetCitizenid, targetSrc, role, adminName, targetDiscord, targetName)
    if targetSrc then
        for _, lvl in ipairs(RSGCore.Config.Server.Permissions) do
            RSGCore.Functions.RemovePermission(targetSrc, lvl)
        end
        RSGCore.Functions.AddPermission(targetSrc, role)
    end

    MySQL.insert([[
        INSERT INTO admin_roles (citizenid, license, discord, name, role, granted_by) VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE role = VALUES(role), granted_by = VALUES(granted_by), name = COALESCE(VALUES(name), name)
    ]], { targetCitizenid, nil, targetDiscord, targetName, role, adminName })
end

local function RemoveAdminRole(targetCitizenid, targetSrc)
    if targetSrc then
        for _, lvl in ipairs(RSGCore.Config.Server.Permissions) do
            RSGCore.Functions.RemovePermission(targetSrc, lvl)
        end
        -- a demoted admin with the panel open would otherwise get auto-banned on their next click
        TriggerClientEvent('rsg-adminmenu:client:forceclose', targetSrc)
    end
    MySQL.update('DELETE FROM admin_roles WHERE citizenid = ?', { targetCitizenid })
end

-- global: grant (role) or remove (role = nil) a staff role, enforcing the
-- hierarchy: you can't grant a role at or above your own, or change anyone at
-- or above your own rank (yourself included). The Owner ('god' ACE) bypasses both.
-- Returns ok, errorMessage.
function ChangeAdminRole(src, targetCitizenid, targetSrc, role, targetName)
    if type(targetCitizenid) ~= 'string' or targetCitizenid == '' then return false, locale('sv_invalid_role') end
    local actorLevel = ActorLevel(src)

    if role then
        local roleLevel = GetRoleLevel(role)
        if roleLevel == 0 then return false, locale('sv_invalid_role') end
        if roleLevel >= actorLevel then return false, locale('sv_cannot_grant_role') end
    end

    local targetLevel
    if targetSrc then
        targetLevel = GetRoleLevel(GetPlayerRole(targetSrc))
    else
        targetLevel = GetRoleLevel(MySQL.scalar.await('SELECT role FROM admin_roles WHERE citizenid = ?', { targetCitizenid }))
    end
    if targetLevel >= actorLevel then return false, locale('sv_target_higher_rank') end

    if role then
        local admin = RSGCore.Functions.GetPlayer(src)
        local adminName = admin and (admin.PlayerData.charinfo.firstname .. ' ' .. admin.PlayerData.charinfo.lastname) or GetPlayerName(src)
        local targetDiscord = targetSrc and RSGCore.Functions.GetIdentifier(targetSrc, 'discord') or nil
        SetAdminRole(targetCitizenid, targetSrc, role, adminName, targetDiscord, targetName)
    else
        RemoveAdminRole(targetCitizenid, targetSrc)
    end
    return true
end

-----------------------------------------------------------------------
-- role hierarchy config (drives the banner + the role dropdowns)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getroleconfig', function(source, cb)
    if not HasAdminPermission(source, 'adminmenu') then return cb({}) end
    local roles = {}
    for _, role in ipairs(RSGCore.Config.Server.Permissions) do
        roles[#roles + 1] = { role = role, level = GetRoleLevel(role), label = LabelForRole(role) }
    end
    cb(roles)
end)

-----------------------------------------------------------------------
-- roster: 3 queries total regardless of staff headcount
-----------------------------------------------------------------------
local function Placeholders(n)
    return ('?, '):rep(n):sub(1, -3)
end

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getadmins', function(source, cb)
    if not HasAdminPermission(source, 'playerinfo') then return cb(nil) end

    MySQL.query('SELECT * FROM admin_roles ORDER BY created_at ASC', {}, function(rows)
        rows = rows or {}
        if #rows == 0 then return cb({}) end

        local citizenids, names = {}, {}
        for _, row in ipairs(rows) do
            citizenids[#citizenids + 1] = row.citizenid
            names[#names + 1] = row.name or ''
        end

        MySQL.query('SELECT citizenid, last_seen FROM player_playtime WHERE citizenid IN (' .. Placeholders(#citizenids) .. ')', citizenids, function(ptRows)
            local lastSeenByCitizen = {}
            for _, r in ipairs(ptRows or {}) do
                lastSeenByCitizen[r.citizenid] = r.last_seen
            end

            -- assigned_admin_id is only a live server-id snapshot, so match by stored name
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
                        local onlineSrc = onlinePlayer and onlinePlayer.PlayerData.source or nil
                        local discordId, discordName, discordAvatarUrl = nil, nil, nil
                        if onlineSrc then
                            discordId, discordName, discordAvatarUrl = GetCachedDiscordIdentity(onlineSrc)
                        end
                        result[#result + 1] = {
                            citizenid = row.citizenid,
                            name = row.name,
                            role = row.role,
                            roleLabel = LabelForRole(row.role),
                            grantedBy = row.granted_by,
                            createdAt = row.created_at,
                            serverId = onlineSrc,
                            online = onlineSrc ~= nil,
                            steamHex = onlineSrc and RSGCore.Functions.GetIdentifier(onlineSrc, 'steam') or nil,
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
-- add admin — target must be online (players has no stored steam hex to resolve offline)
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:addadmin', function(source, cb, data)
    local src = source
    if not HasAdminPermission(src, 'setpermission') then
        return cb({ success = false, message = locale('sv_not_allowed') })
    end
    data = type(data) == 'table' and data or {}

    local targetSrc = nil
    if type(data.steamHex) == 'string' and data.steamHex ~= '' then
        for _, playerId in ipairs(RSGCore.Functions.GetPlayers()) do
            if RSGCore.Functions.GetIdentifier(playerId, 'steam') == data.steamHex then
                targetSrc = playerId
                break
            end
        end
    end
    local target = targetSrc and RSGCore.Functions.GetPlayer(targetSrc)
    if not target then
        return cb({ success = false, message = locale('sv_admin_must_be_online') })
    end

    local targetName = target.PlayerData.charinfo.firstname .. ' ' .. target.PlayerData.charinfo.lastname
    local role = type(data.role) == 'string' and data.role or nil
    if not role then return cb({ success = false, message = locale('sv_invalid_role') }) end

    local ok, message = ChangeAdminRole(src, target.PlayerData.citizenid, targetSrc, role, targetName)
    if not ok then return cb({ success = false, message = message }) end

    LogAdminAction('admin_action', 'high', src, locale('sv_log_granted_role', LabelForRole(role), targetName), locale('sv_log_target', targetName), targetName, targetSrc)
    cb({ success = true })
end)

-----------------------------------------------------------------------
-- change an existing admin's role
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:changeadminrole', function(source, cb, data)
    local src = source
    if not HasAdminPermission(src, 'setpermission') then return cb({ success = false }) end
    data = type(data) == 'table' and data or {}
    local role = type(data.role) == 'string' and data.role or nil
    if not role then return cb({ success = false, message = locale('sv_invalid_role') }) end

    local onlinePlayer = RSGCore.Functions.GetPlayerByCitizenId(data.citizenid)
    local onlineSrc = onlinePlayer and onlinePlayer.PlayerData.source or nil
    local name = SanitizeText(data.name, 255)

    local ok, message = ChangeAdminRole(src, data.citizenid, onlineSrc, role, name)
    if not ok then return cb({ success = false, message = message }) end

    LogAdminAction('admin_action', 'high', src, locale('sv_log_changed_role', (name or data.citizenid), LabelForRole(role)), nil, name, onlineSrc)
    cb({ success = true })
end)

-----------------------------------------------------------------------
-- remove admin access entirely
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:removeadmin', function(source, cb, data)
    local src = source
    if not HasAdminPermission(src, 'setpermission') then return cb({ success = false }) end
    data = type(data) == 'table' and data or {}

    local onlinePlayer = RSGCore.Functions.GetPlayerByCitizenId(data.citizenid)
    local onlineSrc = onlinePlayer and onlinePlayer.PlayerData.source or nil
    local name = SanitizeText(data.name, 255)

    local ok, message = ChangeAdminRole(src, data.citizenid, onlineSrc, nil, name)
    if not ok then return cb({ success = false, message = message }) end

    LogAdminAction('admin_action', 'high', src, locale('sv_log_removed_admin_access', (name or data.citizenid)), nil, name, onlineSrc)
    cb({ success = true })
end)
