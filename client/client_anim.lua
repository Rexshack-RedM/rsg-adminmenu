local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- example:
-- dict = 'ai_gestures@gen_male@standing@speaker'
-- clip = 'empathise_headshake_f_001'
-- flag = 15
-- length = 10000

local function LoadAnimationDic(dict)
  if not HasAnimDictLoaded(dict) then
      RequestAnimDict(dict)
      while not HasAnimDictLoaded(dict) do
          Citizen.Wait(0)
      end
  end
end

-- anim input
RegisterNetEvent('rsg-adminmenu:client:testanimation', function()
    local input = lib.inputDialog(locale('cl_anim_test'), {
        {
            label = locale('cl_anim_dictionary'),
            type = 'input',
            required = true,
        },
        {
            label = locale('cl_anim_name'),
            type = 'input',
            required = true,
        },
        {
            label = locale('cl_anim_flag'),
            type = 'number',
            required = true,
        },
        {
            label = locale('cl_anim_length'),
            type = 'number',
			default = 10000,
            required = true,
        },
    })
    if not input then return end

    TriggerEvent('rsg-adminmenu:client:startanimation', input[1], input[2], input[3], input[4])

end)

RegisterNetEvent('rsg-adminmenu:client:startanimation', function(dict, name, flag, length)
    LoadAnimationDic(dict)
    TaskPlayAnim(cache.ped, dict, name, 2.0, 0, -1, flag, 0, 0, 0, 0)
    Wait(length)
    ClearPedTasks(cache.ped)
end)