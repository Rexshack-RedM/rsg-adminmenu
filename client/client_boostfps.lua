local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterNetEvent('rsg-adminmenu:client:boostfpsShowMenu')
AddEventHandler('rsg-adminmenu:client:boostfpsShowMenu', function()
  lib.registerContext({
      id = 'boost_fps_menu',
      title = 'Boost FPS',
      options = {
        {
            title = 'Optimize Menu',
            description = 'Optimize FPS options',
            icon = 'fas fa-code-merge',
            event = 'rsg-adminmenu:client:boostfpsoptimizeShowMenu',
            arrow = true
        },
        {
            title = 'DeadEye Menu',
            description = 'Deadeye options',
            icon = 'fas fa-code-merge',
            event = 'rsg-adminmenu:client:boostfpsdeadeyeShowMenu',
            arrow = true
        },
        {
          title = 'FPS Boost #1',
          description = 'smg2 intro sunboost',
          icon = 'fas fa-code-merge',
          onSelect = function()
              SetTimecycleModifier('smg2_intro_sunboost') -- 'yell_tunnel_nodirect'
          end,
        },
        {
          title = 'Lights Mode',
          description = 'local Lights thirded',
          icon = 'fas fa-code-merge',
          onSelect = function()
              SetTimecycleModifier('localLights_thirded') -- tunnel
          end,
        },
        {
          title = 'Slasher Mode',
          description = 'game Mode Slasher',
          icon = 'fas fa-code-merge',
          onSelect = function()
              SetTimecycleModifier('gameModeSlasher') -- tunnel
          end,
        },
        {
          title = 'Graphics Reflection',
          description = 'Reset options selected',
          icon = 'fas fa-code-merge',
          onSelect = function()
              SetTimecycleModifier('reduceHDR_Reflection_0pt1')-- MP_Powerplay_blend
              --SetExtraTimecycleModifier('reflection_correct_ambient')
          end,
        },
        {
          title = 'Simple/Reset',
          description = 'Reset options selected',
          icon = 'fa-solid fa-clipboard',
          onSelect = function()
              SetTimecycleModifier()
              ClearTimecycleModifier()
              --ClearExtraTimecycleModifier()
          end,
        }
      }
  })
  lib.showContext('boost_fps_menu')
end)

RegisterNetEvent('rsg-adminmenu:client:boostfpsdeadeyeShowMenu')
AddEventHandler('rsg-adminmenu:client:boostfpsdeadeyeShowMenu', function()
  lib.registerContext({
    id = 'deadeye_fps_menu',
    title = 'DeadEye FPS',
    menu = 'boost_fps_menu',
    onBack = function() end,
    options = {
      {
        title = 'Deadeye Base Mode',
        icon = 'fas fa-code-merge',
        onSelect = function()
            SetTimecycleModifier('DeadEyeBase') -- tunnel
        end,
      },
      {
        title = 'Deadeye Light Mode',
        icon = 'fas fa-code-merge',
        onSelect = function()
            SetTimecycleModifier('DeadEyeLight') -- tunnel
        end,
      },
      {
        title = 'Deadeye Dark Mode',
        icon = 'fas fa-code-merge',
        onSelect = function()
            SetTimecycleModifier('DeadEyeDark') -- tunnel
        end,
      },
      {
        title = 'New Deadeye Mode',
        icon = 'fas fa-code-merge',
        onSelect = function()
            SetTimecycleModifier('newDeadeyeBase') -- tunnel
        end,
      },
    }
  })
  lib.showContext('deadeye_fps_menu')
end)


RegisterNetEvent('rsg-adminmenu:client:boostfpsoptimizeShowMenu')
AddEventHandler('rsg-adminmenu:client:boostfpsoptimizeShowMenu', function()
  lib.registerContext({
    id = 'optimize_fps_menu',
    title = 'Optimize FPS',
    menu = 'boost_fps_menu',
    onBack = function() end,
    options = {
      {
        title = 'colter camp Mode',
        icon = 'fas fa-code-merge',
        onSelect = function()
            SetTimecycleModifier("colter_camp_optimize") -- tunnel
        end,
      },
      {
        title = 'Crn1 Mode',
        icon = 'fas fa-code-merge',
        onSelect = function()
            SetTimecycleModifier('Crn1_optimize') -- tunnel
        end,
      },
      {
        title = 'Dutch3 Mode',
        icon = 'fas fa-code-merge',
        onSelect = function()
            SetTimecycleModifier('Dutch3_optimize') -- tunnel
        end,
      },
      {
        title = 'mob3 main Mode',
        icon = 'fas fa-code-merge',
        onSelect = function()
            SetTimecycleModifier('mob3_optimize_main') -- tunnel
        end,
      },
    }
  })
  lib.showContext('optimize_fps_menu')
end)