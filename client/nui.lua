NUI = {}

local isOpen = false
local notebookActive = false
local NOTEBOOK_SCENARIO = GetHashKey('world_human_write_notebook')

local function StartMenuNotebook()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then return end

    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetNuiFocusKeepInput(false)
    Citizen.InvokeNative(0x524B54361229154F, ped, NOTEBOOK_SCENARIO, -1, true, false, false, false)
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
    SendNuiMessage(json.encode({ action = action, data = data or {} }))
end

function NUI.SetFocus(hasFocus, hasCursor)
    SetNuiFocusKeepInput(false)
    SetNuiFocus(hasFocus, hasCursor ~= false and hasFocus)
end

function NUI.Open(data)
    isOpen = true
    NUI.SetFocus(true, true)
    NUI.SendMessage('open', data or {})
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
    NUI.SetFocus(false, false)
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

-- Hands the active ox_lib locale dictionary to the React UI at boot so every
-- UI label comes from locales/<lang>.json (falls back to en.json).
local function GetUiLocales()
    if lib.getLocales then
        local ok, dict = pcall(lib.getLocales)
        if ok and type(dict) == 'table' and next(dict) then return dict end
    end
    local resource = GetCurrentResourceName()
    local lang = GetConvar('ox:locale', 'en')
    local raw = LoadResourceFile(resource, ('locales/%s.json'):format(lang))
        or LoadResourceFile(resource, 'locales/en.json')
    return raw and json.decode(raw) or {}
end

RegisterNuiCallback('getLocales', function(_, cb)
    cb(GetUiLocales())
end)

RegisterNuiCallback('copyToClipboard', function(data, cb)
    local text = data and data.text
    if type(text) == 'string' and text ~= '' then
        lib.setClipboard(text)
    end
    cb({ success = true })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and isOpen then
        NUI.Close()
    end
end)
