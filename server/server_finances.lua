local RSGCore = exports['rsg-core']:GetCoreObject()

-- add money
RegisterNetEvent('rsg-adminmenu:server:financeadd', function(player, money, amount)
    local Player = RSGCore.Functions.GetPlayer(player)
    Player.Functions.AddMoney(money, amount)
end)

-- remove money
RegisterNetEvent('rsg-adminmenu:server:financeremove', function(player, money, amount)
    local Player = RSGCore.Functions.GetPlayer(player)
    
    if money == 'bank' and Player.PlayerData.money.bank >= amount then
        Player.Functions.RemoveMoney(money, amount)
    elseif money == 'cash' and Player.PlayerData.money.cash >= amount then
        Player.Functions.RemoveMoney(money, amount)
    elseif money == 'bloodmoney' and Player.PlayerData.money.bloodmoney >= amount then
        Player.Functions.RemoveMoney(money, amount)
    else
        TriggerClientEvent('ox_lib:notify', source, {title = Lang:t('lang_116'), description = Lang:t('lang_117')..money..Lang:t('lang_118'), type = 'error' })
    end
    
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getPlayerData', function(player, cb)

    local Player     = RSGCore.Functions.GetPlayer(player)
    local bank       = Player.PlayerData.money["bank"]
    local cash       = Player.PlayerData.money["cash"]
    local bloodmoney = Player.PlayerData.money["bloodmoney"]

    cb({
        bank       = bank,
        cash       = cash,
        bloodmoney = bloodmoney,
    })

end)
