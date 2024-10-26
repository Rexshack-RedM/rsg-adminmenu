local showdoorid = false
lib.locale()

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y =GetScreenCoordFromWorldCoord(x, y, z)
    SetTextScale(0.35, 0.35)
    SetTextFontForCurrentCommand(1)
    SetTextColor(255, 255, 255, 215)
    local str = CreateVarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    SetTextCentre(1)
    DisplayText(str,_x,_y)
end

function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

RegisterNetEvent('rsg-adminmenu:client:toggledoorid', function()
    if not showdoorid then
        showdoorid = true
        lib.notify({ title = locale('cl_door_on'), type = 'inform', duration = 7000 })
    else
        showdoorid = false
        lib.notify({ title = locale('cl_door_off'), type = 'inform', duration = 7000 })
    end
end)

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        if showdoorid then
            for k, v in pairs(Config.DoorHashes) do
                if #(GetEntityCoords(cache.ped) - vector3(v[4], v[5], v[6])) < 2 then
                    sleep = 8
                    DrawText3D(v[4], v[5], v[6]+1.25, locale('cl_door_id') .. tostring( v[1] ) .. "\n".. locale('cl_door_o').. ': '..tostring(v[3]).." \nX: "..tostring(round(v[4], 2)).."\nY: "..tostring(round(v[5], 2)).."\nZ: "..tostring(round(v[6], 2)).."")
                end
            end
        end
        Wait(sleep)
    end
end)
