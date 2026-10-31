local RSGCore = exports['rsg-core']:GetCoreObject()

local MAX_AMOUNT = 1000000

-- only money types rsg-core actually has (cash, gold, bank, bloodmoney).
-- The old valbank/rhobank/blkbank/armbank types were removed from rsg-core;
-- rsg-banking v3 branches replace them and 'bank' forwards to the home branch.
local function ValidMoneyType(moneyType)
    return type(moneyType) == 'string' and RSGCore.Config.Money.MoneyTypes[moneyType] ~= nil
end

local function ParseRequest(src, player, moneyType, amount)
    if not HasAdminPermission(src, 'givemoney') then return nil end
    local Target = RSGCore.Functions.GetPlayer(tonumber(player))
    amount = tonumber(amount)
    if not Target or not amount or amount <= 0 or amount > MAX_AMOUNT or amount ~= amount then
        Notify(src, locale('sv_finan_116'), locale('sv_invalid_input'), 'error')
        return nil
    end
    if not ValidMoneyType(moneyType) then
        Notify(src, locale('sv_finan_116'), locale('sv_invalid_money_type'), 'error')
        return nil
    end
    return Target, math.floor(amount * 100) / 100
end

local function Log(src, Target, logKey, moneyType, amount)
    LogAdminAction('economy', amount >= 100000 and 'high' or 'medium', src, locale(logKey),
        moneyType .. ': $' .. tostring(amount), GetPlayerName(Target.PlayerData.source), Target.PlayerData.source)
end

RegisterNetEvent('rsg-adminmenu:server:financeadd', function(player, moneyType, amount)
    local src = source
    local Target, value = ParseRequest(src, player, moneyType, amount)
    if not Target then return end
    if Target.Functions.AddMoney(moneyType, value, 'rsg-adminmenu:give') then
        Log(src, Target, 'sv_log_gave_money_to_player', moneyType, value)
    end
end)

RegisterNetEvent('rsg-adminmenu:server:financeremove', function(player, moneyType, amount)
    local src = source
    local Target, value = ParseRequest(src, player, moneyType, amount)
    if not Target then return end
    -- RemoveMoney refuses to go below zero (DontAllowMinus) and returns false
    if Target.Functions.RemoveMoney(moneyType, value, 'rsg-adminmenu:remove') then
        Log(src, Target, 'sv_log_removed_money_from_player', moneyType, value)
    else
        Notify(src, locale('sv_finan_116'), locale('sv_finan_117') .. ' ' .. moneyType .. ' ' .. locale('sv_finan_118'), 'error')
    end
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getPlayerData', function(source, cb, player)
    if not HasAdminPermission(source, 'playerinfo') then return cb({}) end
    local Target = RSGCore.Functions.GetPlayer(tonumber(player))
    if not Target then return cb({}) end
    local money = Target.PlayerData.money
    cb({
        cash = money.cash or 0,
        bank = money.bank or 0,
        gold = money.gold or 0,
        bloodmoney = money.bloodmoney or 0,
    })
end)
