NUI = {}

local isOpen = false
local notebookActive = false
local NOTEBOOK_SCENARIO = joaat('world_human_write_notebook')

local function StartMenuNotebook()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return end

    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlaceHash(ped, NOTEBOOK_SCENARIO, -1, true, false, false, false)
    notebookActive = true
end

local function StopMenuNotebook()
    if not notebookActive then return end
    notebookActive = false
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    SetBlockingOfNonTemporaryEvents(ped, false)
    FreezeEntityPosition(ped, false)
end

function NUI.SendMessage(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

function NUI.Open(data)
    if isOpen then return end
    isOpen = true
    SetNuiFocusKeepInput(false)
    SetNuiFocus(true, true)
    NUI.SendMessage('open', data)
    StartMenuNotebook()

    CreateThread(function()
        while isOpen do
            DisableAllControlActions(0)
            Wait(0)
        end
    end)
end

function NUI.Close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    NUI.SendMessage('close')
    StopMenuNotebook()
end

function NUI.IsOpen()
    return isOpen
end

RegisterNuiCallback('close', function(_, cb)
    NUI.Close()
    cb({ success = true })
end)

-- hands the active rsg-core locale dictionary (rsg:locale convar, en fallback
-- is bundled in the UI) to the React app at boot
RegisterNuiCallback('getLocales', function(_, cb)
    cb(locale())
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    StopMenuNotebook()
end)
