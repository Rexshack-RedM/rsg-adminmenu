-- door ID dev tool: shows the hash, model and coords of doors within 2m
DoorIds = {}

local enabled = false

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end
    SetTextScale(0.35, 0.35)
    SetTextFontForCurrentCommand(1)
    SetTextColor(255, 255, 255, 215)
    SetTextCentre(true)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text, Citizen.ResultAsLong()), _x, _y)
end

function DoorIds.IsEnabled()
    return enabled
end

function DoorIds.SetEnabled(state)
    if enabled == state then return end
    enabled = state
    if not enabled then return end

    CreateThread(function()
        -- only doors within 30m are checked each frame; that list is rebuilt once a second
        local nearby, nextScan = {}, 0
        while enabled do
            local coords = GetEntityCoords(PlayerPedId())
            if GetGameTimer() > nextScan then
                nearby = {}
                for _, v in pairs(Config.DoorHashes) do
                    if #(coords - vector3(v[4], v[5], v[6])) < 30.0 then nearby[#nearby + 1] = v end
                end
                nextScan = GetGameTimer() + 1000
            end

            local sleep = 500
            for _, v in ipairs(nearby) do
                if #(coords - vector3(v[4], v[5], v[6])) < 2.0 then
                    sleep = 0
                    DrawText3D(v[4], v[5], v[6] + 1.25, ('%s%s\n%s: %s\nX: %.2f\nY: %.2f\nZ: %.2f'):format(
                        locale('cl_door_id'), v[1], locale('cl_door_o'), v[3], v[4], v[5], v[6]))
                end
            end
            Wait(sleep)
        end
    end)
end
