local RSGCore = exports['rsg-core']:GetCoreObject()

-- add money
RegisterNetEvent('rsg-adminmenu:server:financeadd', function(player, money, amount)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['givemoney']) or IsPlayerAceAllowed(src, 'god') then
        local Player = RSGCore.Functions.GetPlayer(player)
        Player.Functions.AddMoney(money, amount)
        LogAdminAction('economy', (tonumber(amount) or 0) >= 100000 and 'high' or 'medium', src, 'Gave money to player', money .. ': $' .. tostring(amount), GetPlayerName(player), player)
    end
end)

-- remove money
RegisterNetEvent('rsg-adminmenu:server:financeremove', function(player, money, amount)
    local src = source
    if not (RSGCore.Functions.HasPermission(src, permissions['givemoney']) or IsPlayerAceAllowed(src, 'god')) then
        return
    end

    local Player = RSGCore.Functions.GetPlayer(player)

    if money == 'bank' and Player.PlayerData.money.bank >= amount then
        Player.Functions.RemoveMoney(money, amount)
        LogAdminAction('economy', (tonumber(amount) or 0) >= 100000 and 'high' or 'medium', src, 'Removed money from player', money .. ': $' .. tostring(amount), GetPlayerName(player), player)
    elseif money == 'valbank' and Player.PlayerData.money.valbank >= amount then
        Player.Functions.RemoveMoney(money, amount)
        LogAdminAction('economy', (tonumber(amount) or 0) >= 100000 and 'high' or 'medium', src, 'Removed money from player', money .. ': $' .. tostring(amount), GetPlayerName(player), player)
    elseif money == 'rhobank' and Player.PlayerData.money.rhobank >= amount then
        Player.Functions.RemoveMoney(money, amount)
        LogAdminAction('economy', (tonumber(amount) or 0) >= 100000 and 'high' or 'medium', src, 'Removed money from player', money .. ': $' .. tostring(amount), GetPlayerName(player), player)
    elseif money == 'blkbank' and Player.PlayerData.money.blkbank >= amount then
        Player.Functions.RemoveMoney(money, amount)
        LogAdminAction('economy', (tonumber(amount) or 0) >= 100000 and 'high' or 'medium', src, 'Removed money from player', money .. ': $' .. tostring(amount), GetPlayerName(player), player)
    elseif money == 'armbank' and Player.PlayerData.money.armbank >= amount then
        Player.Functions.RemoveMoney(money, amount)
        LogAdminAction('economy', (tonumber(amount) or 0) >= 100000 and 'high' or 'medium', src, 'Removed money from player', money .. ': $' .. tostring(amount), GetPlayerName(player), player)
    elseif money == 'cash' and Player.PlayerData.money.cash >= amount then
        Player.Functions.RemoveMoney(money, amount)
        LogAdminAction('economy', (tonumber(amount) or 0) >= 100000 and 'high' or 'medium', src, 'Removed money from player', money .. ': $' .. tostring(amount), GetPlayerName(player), player)
    elseif money == 'bloodmoney' and Player.PlayerData.money.bloodmoney >= amount then
        Player.Functions.RemoveMoney(money, amount)
        LogAdminAction('economy', (tonumber(amount) or 0) >= 100000 and 'high' or 'medium', src, 'Removed money from player', money .. ': $' .. tostring(amount), GetPlayerName(player), player)
    else
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_finan_116'), description = locale('sv_finan_117') ..' '..money.. ' '.. locale('sv_finan_118'), type = 'error' })
    end
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getPlayerData', function(source, cb, player)

    local Player     = RSGCore.Functions.GetPlayer(player)
    local bank       = Player.PlayerData.money['bank']
    local valbank    = Player.PlayerData.money['valbank']
    local rhobank    = Player.PlayerData.money['rhobank']
    local blkbank    = Player.PlayerData.money['blkbank']
    local armbank    = Player.PlayerData.money['armbank']
    local cash       = Player.PlayerData.money['cash']
    local bloodmoney = Player.PlayerData.money['bloodmoney']

    cb({
        bank       = bank,
        valbank    = valbank,
        rhobank    = rhobank,
        blkbank    = blkbank,
        armbank    = armbank,
        cash       = cash,
        bloodmoney = bloodmoney,
    })

end)
