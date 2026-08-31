NUI = {}

local isOpen = false

function NUI.SendMessage(action, data)
    SendNuiMessage(json.encode({ action = action, data = data or {} }))
end

function NUI.SetFocus(hasFocus, hasCursor)
    SetNuiFocus(hasFocus, hasCursor ~= false and hasFocus)
end

function NUI.Open(data)
    isOpen = true
    NUI.SetFocus(true, true)
    NUI.SendMessage('open', data or {})
end

function NUI.Close()
    if not isOpen then return end
    isOpen = false
    NUI.SetFocus(false, false)
    NUI.SendMessage('close')
end

function NUI.IsOpen()
    return isOpen
end

RegisterNuiCallback('close', function(_, cb)
    NUI.Close()
    cb({ success = true })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and isOpen then
        NUI.Close()
    end
end)
