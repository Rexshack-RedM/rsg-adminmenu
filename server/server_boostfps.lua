local RSGCore = exports['rsg-core']:GetCoreObject()

RSGCore.Commands.Add('boostfps', "", {}, false, function(source)
    local src = source
    TriggerClientEvent('rsg-adminmenu:client:boostfpsShowMenu', src)
end, 'user')