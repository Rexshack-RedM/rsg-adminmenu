local RSGCore = exports['rsg-core']:GetCoreObject()

-- add money
RegisterNetEvent('rsg-adminmenu:server:financeadd', function(player, money, amount)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['givemoney']) or IsPlayerAceAllowed(src, 'command') then
        local Player = RSGCore.Functions.GetPlayer(player)
        Player.Functions.AddMoney(money, amount)
    end
end)

-- remove money
RegisterNetEvent('rsg-adminmenu:server:financeremove', function(player, money, amount)
    local Player = RSGCore.Functions.GetPlayer(player)

    if money == 'bank' and Player.PlayerData.money.bank >= amount then
        Player.Functions.RemoveMoney(money, amount)
    elseif money == 'valbank' and Player.PlayerData.money.valbank >= amount then
        Player.Functions.RemoveMoney(money, amount)
    elseif money == 'rhobank' and Player.PlayerData.money.rhobank >= amount then
        Player.Functions.RemoveMoney(money, amount)
    elseif money == 'blkbank' and Player.PlayerData.money.blkbank >= amount then
        Player.Functions.RemoveMoney(money, amount)
    elseif money == 'armbank' and Player.PlayerData.money.armbank >= amount then
        Player.Functions.RemoveMoney(money, amount)
    elseif money == 'cash' and Player.PlayerData.money.cash >= amount then
        Player.Functions.RemoveMoney(money, amount)
    elseif money == 'bloodmoney' and Player.PlayerData.money.bloodmoney >= amount then
        Player.Functions.RemoveMoney(money, amount)
    else
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_finan_116'), description = locale('sv_finan_117') ..' '..money.. ' '.. locale('sv_finan_118'), type = 'error' })
    end
end)

RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getPlayerData', function(player, cb)

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
