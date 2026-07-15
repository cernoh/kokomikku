local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local logger = require("logger")
local _ = require("gettext")

local Backend = require("Backend")

--- @class KomikkuSettings
--- Configuration for the Komikku server URL.
local KomikkuSettings = {}

--- Shows the server URL configuration dialog.
function KomikkuSettings:show()
    local dialog
    dialog = InputDialog:new{
        title = _("Komikku Server URL"),
        input = Backend.getBaseUrl(),
        input_hint = "http://192.168.1.100:8080",
        input_type = "string",
        description = _("Enter the IP address and port of your Android device running Komikku.\nFind it in the Komikku app notification when the server is running."),
        buttons = {
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = _("Test"),
                    callback = function()
                        local url = dialog:getInputText()
                        Backend.setBaseUrl(url)
                        if Backend.isServerReachable() then
                            UIManager:show(InfoMessage:new{
                                text = _("Connection successful!"),
                                timeout = 2,
                            })
                        else
                            UIManager:show(InfoMessage:new{
                                text = _("Cannot reach server."),
                                timeout = 3,
                            })
                        end
                    end,
                },
                {
                    text = _("Save"),
                    is_enter_default = true,
                    callback = function()
                        local url = dialog:getInputText()
                        -- Strip trailing slash
                        url = url:gsub("/$", "")
                        Backend.setBaseUrl(url)
                        UIManager:close(dialog)
                        UIManager:show(InfoMessage:new{
                            text = _("Server URL saved: ") .. url,
                            timeout = 2,
                        })
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

return KomikkuSettings
