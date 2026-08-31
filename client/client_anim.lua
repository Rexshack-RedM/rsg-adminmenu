local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local function LoadAnimationDic(dict)
  if not HasAnimDictLoaded(dict) then
      RequestAnimDict(dict)
      while not HasAnimDictLoaded(dict) do
          Citizen.Wait(0)
      end
  end
end

RegisterNuiCallback('testAnimation', function(data, cb)
    TriggerEvent('rsg-adminmenu:client:startanimation', data.dict, data.name, tonumber(data.flag) or 0, tonumber(data.length) or 10000)
    cb({ success = true })
end)

RegisterNetEvent('rsg-adminmenu:client:startanimation', function(dict, name, flag, length)
    LoadAnimationDic(dict)
    TaskPlayAnim(cache.ped, dict, name, 2.0, 0, -1, flag, 0, 0, 0, 0)
    Wait(length)
    ClearPedTasks(cache.ped)
end)
