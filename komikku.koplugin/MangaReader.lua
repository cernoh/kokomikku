local ReaderUI = require("apps/reader/readerui")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ConfirmBox = require("ui/widget/confirmbox")
local logger = require("logger")
local _ = require("gettext")

local Backend = require("Backend")

--- @class MangaReader
--- Singleton that opens manga CBZs in KOReader's reader and tracks progress.
local MangaReader = {
    is_showing = false,
    on_return_callback = nil,
    manga = nil,
    chapter = nil,
    pages = nil,
}

--- Opens a CBZ file in KOReader's reader.
--- @param path string Path to the CBZ file
--- @param manga table The manga metadata
--- @param chapter table The chapter metadata
--- @param pages table[] The page list
function MangaReader:show(path, manga, chapter, pages)
    self.manga = manga
    self.chapter = chapter
    self.pages = pages
    self.is_showing = true

    -- Report progress when chapter is opened
    Backend.reportProgress(chapter.id, 0)

    ReaderUI:showReader(path)
end

--- Fallback: opens a directory of images using KOReader's image viewer.
--- @param dir string Path to the directory containing page images
--- @param manga table
--- @param chapter table
--- @param pages table[]
function MangaReader:showFromDirectory(dir, manga, chapter, pages)
    -- Find the first image in the directory
    local lfs = require("libs/libkoreader-lfs")
    local first_image = nil
    for entry in lfs.dir(dir) do
        if entry:match("%.jpe?g$") or entry:match("%.png$") or entry:match("%.webp$") then
            first_image = dir .. "/" .. entry
            break
        end
    end

    if first_image then
        self:show(first_image, manga, chapter, pages)
    end
end

return MangaReader
