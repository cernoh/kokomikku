local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Trapper = require("ui/trapper")
local logger = require("logger")
local _ = require("gettext")
local DataStorage = require("datastorage")

local Backend = require("Backend")
local MangaReader = require("MangaReader")

local lfs = require("libs/libkoreader-lfs")
local socket_url = require("socket.url")

--- @class ChapterListing
--- Shows chapters for a manga and handles opening them for reading.
local ChapterListing = Menu:extend {
    no_title = false,
    is_borderless = true,
    manga = nil,
    chapters = {},
}

function ChapterListing:init()
    self.chapters = self.chapters or {}
    Menu.init(self)
end

function ChapterListing:onClose()
    UIManager:close(self)
end

function ChapterListing:onReturn()
    self:onClose()
end

--- Fetches chapters for a manga and displays the list.
--- @param manga table The manga object (must include sourceId)
function ChapterListing:fetchAndShow(manga)
    self.manga = manga
    self.title = manga.title

    Trapper:wrap(function()
        local loading = InfoMessage:new{ text = _("Loading chapters...") }
        UIManager:show(loading)
        UIManager:forceRePaint()

        local response = Backend.getChapters(manga.id)
        UIManager:close(loading)
        UIManager:forceRePaint()

        if response.type == "ERROR" then
            UIManager:show(InfoMessage:new{
                text = _("Failed to load chapters: ") .. response.message,
                timeout = 3,
            })
            return
        end

        self.chapters = response.body or {}
        -- Sort by source order descending (newest at top)
        table.sort(self.chapters, function(a, b)
            return a.sourceOrder > b.sourceOrder
        end)
        self:updateItems()
        UIManager:show(self)
    end)
end

function ChapterListing:updateItems()
    local item_table = self:generateItemTable()
    self:switchItemTable(nil, item_table)
    UIManager:setDirty(self, "ui")
end

function ChapterListing:generateItemTable()
    local item_table = {}

    if #self.chapters == 0 then
        table.insert(item_table, {
            text = _("No chapters available"),
            mandatory = "",
        })
        return item_table
    end

    for _, chapter in ipairs(self.chapters) do
        local display_name = chapter.name
        local read_marker = chapter.read and "\x{2713} " or ""
        local scanlator = chapter.scanlator and (" [" .. chapter.scanlator .. "]") or ""

        table.insert(item_table, {
            text = read_marker .. display_name .. scanlator,
            mandatory = chapter.chapterNumber >= 0 and string.format("Ch. %g", chapter.chapterNumber) or "",
            chapter = chapter,
        })
    end

    return item_table
end

function ChapterListing:onMenuChoice(item)
    if not item.chapter then return end
    Trapper:wrap(function()
        self:openChapter(item.chapter)
    end)
end

--- Downloads pages for a chapter (proxied through the server), creates a CBZ, opens it.
--- @param chapter table
function ChapterListing:openChapter(chapter)
    local loading = InfoMessage:new{ text = _("Downloading pages...") }
    UIManager:show(loading)
    UIManager:forceRePaint()

    -- Fetch page list
    local page_response = Backend.getPages(chapter.id)
    if page_response.type == "ERROR" then
        UIManager:close(loading)
        UIManager:show(InfoMessage:new{
            text = _("Failed to load pages: ") .. page_response.message,
            timeout = 3,
        })
        return
    end

    local pages = page_response.body or {}
    if #pages == 0 then
        UIManager:close(loading)
        UIManager:show(InfoMessage:new{
            text = _("No pages found for this chapter."),
            timeout = 3,
        })
        return
    end

    -- Create temp directory for this chapter
    local cache_dir = DataStorage:getDataDir() .. "/komikku_cache"
    local temp_dir = cache_dir .. "/" .. chapter.id
    os.execute("mkdir -p '" .. temp_dir .. "'")

    -- Download each page image through the server proxy
    local source_id = self.manga.sourceId
    local success_count = 0

    for i, page in ipairs(pages) do
        local ext = self:guessExtension(page.imageUrl)
        local filepath = temp_dir .. "/" .. string.format("%04d", i) .. "." .. ext

        -- Build proxy URL: server fetches the image with proper source headers
        local proxy_url = Backend.getProxyImageUrl(page.imageUrl, source_id)

        if not lfs.attributes(filepath, "mode") then
            local ok = Backend.downloadFile(proxy_url, filepath)
            if ok then
                success_count = success_count + 1
            else
                logger.warn("Failed to download page", i, page.imageUrl)
            end
        else
            success_count = success_count + 1
        end
    end

    UIManager:close(loading)
    UIManager:forceRePaint()

    if success_count == 0 then
        UIManager:show(InfoMessage:new{
            text = _("Failed to download any pages."),
            timeout = 3,
        })
        return
    end

    -- Create CBZ from the downloaded images
    local cbz_path = cache_dir .. "/chapter_" .. chapter.id .. ".cbz"
    local cmd = string.format("cd '%s' && zip -q -j '%s' * 2>/dev/null", temp_dir, cbz_path)
    local zip_ok = os.execute(cmd)

    if zip_ok and lfs.attributes(cbz_path, "mode") then
        -- Report progress
        Backend.reportProgress(chapter.id, 0)
        MangaReader:show(cbz_path, self.manga, chapter, pages)
    else
        -- Fallback: open the first downloaded image
        local ext = self:guessExtension(pages[1].imageUrl)
        local first_page = temp_dir .. "/" .. string.format("%04d", 1) .. "." .. ext
        if lfs.attributes(first_page, "mode") then
            Backend.reportProgress(chapter.id, 0)
            MangaReader:show(first_page, self.manga, chapter, pages)
        else
            UIManager:show(InfoMessage:new{
                text = _("Failed to prepare chapter for reading."),
                timeout = 3,
            })
        end
    end
end

function ChapterListing:guessExtension(url)
    if not url then return "jpg" end
    local ext = url:match("%.([a-zA-Z]+)%??") or url:match("%.([a-zA-Z]+)$")
    if ext then
        ext = ext:lower()
        if ext == "png" or ext == "gif" or ext == "webp" or ext == "jpeg" or ext == "jpg" then
            return ext
        end
    end
    return "jpg"
end

return ChapterListing
