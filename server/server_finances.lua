local RSGCore = exports['rsg-core']:GetCoreObject()

local moneyTypes = { 'bank', 'valbank', 'rhobank', 'blkbank', 'armbank', 'cash', 'bloodmoney' }
local validMoneyType = {}
for _, t in ipairs(moneyTypes) do validMoneyType[t] = true end

-- shared validation for add/remove: permission (ban on tamper is not used here
-- since the panel can legitimately be open while a role is revoked), online
-- target, known money type and a positive amount
local function PrepareFinance(src, player, moneyType, amount)
    if not HasAdminPermission(src, 'givemoney') then return nil end
    local target = tonumber(player)
    local Player = target and RSGCore.Functions.GetPlayer(target)
    amount = tonumber(amount)
    if not Player or not validMoneyType[moneyType] or not amount or amount <= 0 or amount ~= amount or amount == math.huge then
        NotifyPlayer(src, locale('sv_finan_116'), locale('sv_invalid_value'), 'error')
        return nil
    end
    return Player, target, math.floor(amount * 100 + 0.5) / 100
end

local function LogFinance(src, target, action, moneyType, amount)
    LogAdminAction('economy', amount >= 100000 and 'high' or 'medium', src, locale(action), moneyType .. ': $' .. amount, GetPlayerName(target), target)
end

RegisterNetEvent('rsg-adminmenu:server:financeadd', function(player, moneyType, amount)
    local src = source
    local Player, target
    Player, target, amount = PrepareFinance(src, player, moneyType, amount)
    if not Player then return end
    if Player.Functions.AddMoney(moneyType, amount, 'admin-menu') then
        LogFinance(src, target, 'sv_log_gave_money_to_player', moneyType, amount)
    end
end)

RegisterNetEvent('rsg-adminmenu:server:financeremove', function(player, moneyType, amount)
    local src = source
    local Player, target
    Player, target, amount = PrepareFinance(src, player, moneyType, amount)
    if not Player then return end
    if not CanActOn(src, target) then
        return NotifyPlayer(src, locale('sv_101'), locale('sv_target_higher_rank'), 'error')
    end
    if (Player.PlayerData.money[moneyType] or 0) < amount or not Player.Functions.RemoveMoney(moneyType, amount, 'admin-menu') then
        return NotifyPlayer(src, locale('sv_finan_116'), locale('sv_finan_117') .. ' ' .. moneyType .. ' ' .. locale('sv_finan_118'), 'error')
    end
    LogFinance(src, target, 'sv_log_removed_money_from_player', moneyType, amount)
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getPlayerData', function(source, cb, player)
    if not HasAdminPermission(source, 'givemoney') then return cb({}) end
    local Player = RSGCore.Functions.GetPlayer(tonumber(player) or -1)
    if not Player then return cb({}) end

    local result = {}
    for _, t in ipairs(moneyTypes) do result[t] = Player.PlayerData.money[t] end
    cb(result)
end)
