local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local logger = require("logger")
local _ = require("gettext")

local Backend = require("Backend")
local LibraryView = require("LibraryView")
local KomikkuSettings = require("Settings")

local Komikku = InputContainer:extend({
    name = "komikku",
})

function Komikku:init()
    self.ui.menu:registerToMainMenu(self)
end

function Komikku:addToMainMenu(menu_items)
    menu_items.komikku = {
        text = _("Komikku"),
        sub_item_table = {
            {
                text = _("Browse library"),
                callback = function()
                    self:openLibrary()
                end,
            },
            {
                text = _("Server settings"),
                callback = function()
                    KomikkuSettings:show()
                end,
            },
        },
    }
end

function Komikku:openLibrary()
    if not Backend.isServerReachable() then
        UIManager:show(InfoMessage:new{
            text = _("Cannot connect to Komikku server.\nCheck Settings > Komikku > Server settings to configure the server URL."),
            timeout = 4,
        })
        return
    end
    LibraryView:fetchAndShow()
end

return Komikku
