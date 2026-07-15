local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Trapper = require("ui/trapper")
local logger = require("logger")
local _ = require("gettext")

local Backend = require("Backend")
local ChapterListing = require("ChapterListing")

--- @class LibraryView
--- Displays the user's manga library from the Komikku server.
local LibraryView = Menu:extend {
    title = _("Komikku Library"),
    no_title = false,
    is_borderless = true,
    mangas = {},
}

function LibraryView:init()
    self.mangas = self.mangas or {}
    Menu.init(self)
end

function LibraryView:onClose()
    UIManager:close(self)
end

function LibraryView:onReturn()
    self:onClose()
end

--- Fetches the library from the server and displays it.
function LibraryView:fetchAndShow()
    Trapper:wrap(function()
        local loading = InfoMessage:new{ text = _("Loading library...") }
        UIManager:show(loading)
        UIManager:forceRePaint()

        local response = Backend.getLibrary()
        UIManager:close(loading)
        UIManager:forceRePaint()

        if response.type == "ERROR" then
            UIManager:show(InfoMessage:new{
                text = _("Failed to load library: ") .. response.message,
                timeout = 3,
            })
            return
        end

        LibraryView.mangas = response.body or {}
        LibraryView:updateItems()
        UIManager:show(LibraryView)
    end)
end

function LibraryView:updateItems()
    local item_table = self:generateItemTable()
    self:switchItemTable(nil, item_table)
    UIManager:setDirty(self, "ui")
end

function LibraryView:generateItemTable()
    local item_table = {}

    if #self.mangas == 0 then
        table.insert(item_table, {
            text = _("Library is empty"),
            mandatory = "",
        })
        return item_table
    end

    for _, manga in ipairs(self.mangas) do
        local subtitle = manga.author or ""
        if manga.genre and #manga.genre > 0 then
            subtitle = subtitle .. " | " .. table.concat(manga.genre, ", ")
        end

        table.insert(item_table, {
            text = manga.title,
            mandatory = subtitle,
            manga = manga,
        })
    end

    return item_table
end

function LibraryView:onMenuChoice(item)
    if not item.manga then return end
    Trapper:wrap(function()
        ChapterListing:fetchAndShow(item.manga)
    end)
end

function LibraryView:onMenuHold(item)
    if not item.manga then return end
    local dialog
    dialog = require("ui/widget/buttondialog"):new{
        title = item.manga.title,
        buttons = {
            {
                {
                    text = _("Close"),
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

return LibraryView
