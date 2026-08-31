local RSGCore = exports['rsg-core']:GetCoreObject()

local resourceStartTime = os.time()

-----------------------------------------------------------------------
-- self-migrating schema: don't depend on the SQL files having been run
-- by hand — create/repair everything this resource needs on startup.
-----------------------------------------------------------------------
MySQL.query([[
    CREATE TABLE IF NOT EXISTS `player_playtime` (
        `citizenid` VARCHAR(50) NOT NULL,
        `minutes` INT(11) NOT NULL DEFAULT 0,
        `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])

MySQL.query([[
    CREATE TABLE IF NOT EXISTS `admin_activity_log` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `sample_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `online_count` INT(11) NOT NULL DEFAULT 0,
        `total_money` DECIMAL(15,2) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])

-- covers installs that created admin_activity_log before total_money existed
MySQL.query("ALTER TABLE `admin_activity_log` ADD COLUMN IF NOT EXISTS `total_money` DECIMAL(15,2) NOT NULL DEFAULT 0")

-----------------------------------------------------------------------
-- playtime tracking (player_playtime, self-migrated above)
-----------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(60000)

        for _, Player in pairs(RSGCore.Functions.GetRSGPlayers()) do
            local citizenid = Player.PlayerData.citizenid
            if citizenid then
                MySQL.insert(
                    'INSERT INTO player_playtime (citizenid, minutes, last_seen) VALUES (?, 1, NOW()) ON DUPLICATE KEY UPDATE minutes = minutes + 1, last_seen = NOW()',
                    { citizenid }
                )
            end
        end
    end
end)

-----------------------------------------------------------------------
-- helper: sum every numeric field in a money table
-----------------------------------------------------------------------
local function SumMoneyTable(money)
    if type(money) ~= 'table' then return 0 end
    local total = 0
    for _, value in pairs(money) do
        if type(value) == 'number' then
            total = total + value
        end
    end
    return total
end

local function DecodeMoney(moneyJson)
    if not moneyJson then return {} end
    local ok, money = pcall(json.decode, moneyJson)
    if not ok or type(money) ~= 'table' then return {} end
    return money
end

-----------------------------------------------------------------------
-- helper: money for a citizenid — the DB `players` row is only as fresh as that
-- character's last autosave, so an online player's live bank/cash changes (a
-- deposit, an admin adjustment, etc.) won't show up there until their next save.
-- Read straight from the live session when they're online; DB is the fallback.
-----------------------------------------------------------------------
local function GetLiveOrStoredMoney(citizenid, dbMoneyJson)
    local onlinePlayer = citizenid and RSGCore.Functions.GetPlayerByCitizenId(citizenid) or nil
    if onlinePlayer and onlinePlayer.PlayerData.money then
        return onlinePlayer.PlayerData.money, true
    end
    return DecodeMoney(dbMoneyJson), false
end

-----------------------------------------------------------------------
-- helper: average ping across everyone currently online
-----------------------------------------------------------------------
local function GetAveragePing()
    local players = RSGCore.Functions.GetPlayers()
    if #players == 0 then return 0 end

    local total = 0
    for _, playerId in ipairs(players) do
        total = total + GetPlayerPing(playerId)
    end
    return math.floor(total / #players)
end

-----------------------------------------------------------------------
-- activity sampling (admin_activity_log, self-migrated above)
-----------------------------------------------------------------------
local function SampleActivity()
    local onlineCount = #RSGCore.Functions.GetPlayers()

    MySQL.query('SELECT citizenid, money FROM players', {}, function(rows)
        local totalMoney = 0
        for _, row in ipairs(rows or {}) do
            totalMoney = totalMoney + SumMoneyTable((GetLiveOrStoredMoney(row.citizenid, row.money)))
        end
        MySQL.insert('INSERT INTO admin_activity_log (online_count, total_money) VALUES (?, ?)', { onlineCount, totalMoney })
    end)
end

CreateThread(function()
    Wait(5000) -- give the CREATE TABLE / ALTER TABLE queries above time to land first
    SampleActivity()

    while true do
        Wait(15 * 60000)
        SampleActivity()
    end
end)

-----------------------------------------------------------------------
-- dashboard stats: online count, server-wide money total, uptime, leaderboard
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getdashboardstats', function(source, cb)
    local onlineCount = #RSGCore.Functions.GetPlayers()

    -- reads the value SampleActivity() already computed (every 15 minutes),
    -- rather than re-scanning and re-decoding money for every character
    -- ever created on this server on every single dashboard load. On a
    -- server with a large player history that full-table scan is real,
    -- avoidable cost for a stat that doesn't need to be second-fresh anyway.
    MySQL.scalar('SELECT total_money FROM admin_activity_log ORDER BY sample_time DESC LIMIT 1', {}, function(cachedTotal)
        local totalMoney = tonumber(cachedTotal) or 0

        MySQL.query([[
            SELECT pt.citizenid, pt.minutes, p.name, p.charinfo, p.job, p.money
            FROM player_playtime pt
            LEFT JOIN players p ON p.citizenid = pt.citizenid
            WHERE p.citizenid IS NOT NULL
            ORDER BY pt.minutes DESC
            LIMIT 10
        ]], {}, function(leaderRows)
            local leaderboard = {}

            for i, row in ipairs(leaderRows or {}) do
                local charinfo = row.charinfo and select(2, pcall(json.decode, row.charinfo)) or nil
                local job = row.job and select(2, pcall(json.decode, row.job)) or nil
                charinfo = type(charinfo) == 'table' and charinfo or {}
                job = type(job) == 'table' and job or {}

                local onlinePlayer = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)
                local jobLabel = job.label or 'Unemployed'
                if onlinePlayer and onlinePlayer.PlayerData.job then
                    jobLabel = onlinePlayer.PlayerData.job.label
                end

                local liveMoney = (onlinePlayer and onlinePlayer.PlayerData.money) or DecodeMoney(row.money)

                local discordId, discordName, discordAvatarUrl = nil, nil, nil
                if onlinePlayer then
                    discordId, discordName, discordAvatarUrl = GetCachedDiscordIdentity(onlinePlayer.PlayerData.source)
                end

                leaderboard[#leaderboard + 1] = {
                    rank = i,
                    citizenid = row.citizenid,
                    name = (charinfo.firstname or '?') .. ' ' .. (charinfo.lastname or ''),
                    accountName = row.name or '',
                    job = jobLabel,
                    online = onlinePlayer ~= nil,
                    playtimeMinutes = row.minutes or 0,
                    money = SumMoneyTable(liveMoney),
                    discordId = discordId,
                    discordName = discordName,
                    discordAvatarUrl = discordAvatarUrl,
                }
            end

            cb({
                onlineCount = onlineCount,
                totalMoney = totalMoney,
                serverUptimeSeconds = os.time() - resourceStartTime,
                topPlayer = leaderboard[1] or nil,
                leaderboard = leaderboard,
            })
        end)
    end)
end)

-----------------------------------------------------------------------
-- statistics page: player activity history, job distribution, economy, performance
-----------------------------------------------------------------------
local moneyTypes = { 'cash', 'bank', 'bloodmoney', 'valbank', 'rhobank', 'blkbank', 'armbank' }

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getstatistics', function(source, cb)
    -- DATE_FORMAT is used (rather than DATE()) so this always comes back as a plain
    -- string — a raw DATE column gets deserialized as a JS Date/epoch value somewhere
    -- along the oxmysql -> Lua -> JSON round trip, which showed up client-side as a
    -- huge millisecond number instead of a date.
    MySQL.query([[
        SELECT DATE_FORMAT(sample_time, '%Y-%m-%d') as day, AVG(online_count) as avg_players, MAX(online_count) as peak_players
        FROM admin_activity_log
        WHERE sample_time >= (NOW() - INTERVAL 14 DAY)
        GROUP BY DATE_FORMAT(sample_time, '%Y-%m-%d')
        ORDER BY day ASC
    ]], {}, function(activityRows)
        local activity = {}
        for _, row in ipairs(activityRows or {}) do
            activity[#activity + 1] = {
                date = tostring(row.day),
                averagePlayers = tonumber(row.avg_players) or 0,
                peakPlayers = tonumber(row.peak_players) or 0,
            }
        end

        MySQL.query([[
            SELECT DATE_FORMAT(sample_time, '%Y-%m-%d') as day, AVG(total_money) as avg_money
            FROM admin_activity_log
            WHERE sample_time >= (NOW() - INTERVAL 14 DAY)
            GROUP BY DATE_FORMAT(sample_time, '%Y-%m-%d')
            ORDER BY day ASC
        ]], {}, function(moneyRows)
            local dailyMoney = {}
            for _, row in ipairs(moneyRows or {}) do
                dailyMoney[#dailyMoney + 1] = {
                    date = tostring(row.day),
                    averageMoney = tonumber(row.avg_money) or 0,
                }
            end

            MySQL.query([[
                SELECT DATE_FORMAT(sample_time, '%Y-%m-%d %H:00:00') as hour, AVG(online_count) as avg_players, MAX(online_count) as peak_players
                FROM admin_activity_log
                WHERE sample_time >= (NOW() - INTERVAL 24 HOUR)
                GROUP BY hour
                ORDER BY hour ASC
            ]], {}, function(hourlyRows)
                local hourlyActivity = {}
                for _, row in ipairs(hourlyRows or {}) do
                    hourlyActivity[#hourlyActivity + 1] = {
                        hour = tostring(row.hour),
                        averagePlayers = tonumber(row.avg_players) or 0,
                        peakPlayers = tonumber(row.peak_players) or 0,
                    }
                end

                MySQL.query('SELECT citizenid, job, money FROM players', {}, function(rows)
                    local jobCounts = {}
                    local moneyTotals = {}
                    for _, t in ipairs(moneyTypes) do moneyTotals[t] = 0 end
                    local liveTotalToday = 0

                    for _, row in ipairs(rows or {}) do
                        local onlinePlayer = row.citizenid and RSGCore.Functions.GetPlayerByCitizenId(row.citizenid) or nil

                        local label
                        if onlinePlayer and onlinePlayer.PlayerData.job then
                            label = onlinePlayer.PlayerData.job.label
                        else
                            local ok, job = pcall(json.decode, row.job or '{}')
                            label = (ok and type(job) == 'table' and job.label) or 'Unemployed'
                        end
                        jobCounts[label] = (jobCounts[label] or 0) + 1

                        local money = (onlinePlayer and onlinePlayer.PlayerData.money) or DecodeMoney(row.money)
                        for _, t in ipairs(moneyTypes) do
                            if type(money[t]) == 'number' then
                                moneyTotals[t] = moneyTotals[t] + money[t]
                            end
                        end
                        liveTotalToday = liveTotalToday + SumMoneyTable(money)
                    end

                    local jobDistribution = {}
                    for label, count in pairs(jobCounts) do
                        jobDistribution[#jobDistribution + 1] = { job = label, count = count }
                    end
                    table.sort(jobDistribution, function(a, b) return a.count > b.count end)

                    local moneyByType = {}
                    for _, t in ipairs(moneyTypes) do
                        moneyByType[#moneyByType + 1] = { type = t, total = moneyTotals[t] }
                    end

                    -- today's bar is replaced with the live total (computed above, same as the
                    -- dashboard) rather than left as an average of stale historical snapshots —
                    -- otherwise a deposit made seconds ago wouldn't show until the next 15-minute
                    -- sample fires, which read as "the chart is just wrong".
                    local todayStr = os.date('%Y-%m-%d')
                    local foundToday = false
                    for _, entry in ipairs(dailyMoney) do
                        if entry.date == todayStr then
                            entry.averageMoney = liveTotalToday
                            foundToday = true
                            break
                        end
                    end
                    if not foundToday then
                        dailyMoney[#dailyMoney + 1] = { date = todayStr, averageMoney = liveTotalToday }
                    end

                    cb({
                        players = {
                            activity = activity,
                            jobDistribution = jobDistribution,
                        },
                        economy = {
                            dailyMoney = dailyMoney,
                            moneyByType = moneyByType,
                        },
                        performance = {
                            onlineCount = #RSGCore.Functions.GetPlayers(),
                            resourceCount = GetNumResources(),
                            serverUptimeSeconds = os.time() - resourceStartTime,
                            averagePing = GetAveragePing(),
                            hourlyActivity = hourlyActivity,
                        },
                    })
                end)
            end)
        end)
    end)
end)
