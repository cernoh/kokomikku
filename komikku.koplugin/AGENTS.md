# komikku.koplugin

KOReader plugin that browses and reads manga from the Komikku Android app over WiFi.

## Language & Stack

- Lua 5.1 (LuaJIT, as used by KOReader)
- Uses KOReader widgets (Menu, InputDialog, InfoMessage, Trapper)
- HTTP via LuaSocket (socket.http, ltn12)
- JSON via rapidjson (bundled with KOReader)

## Architecture

Plugin talks to the Komikku HTTP server (NanoHTTPD in the Android app) over WiFi.

Flow: `main.lua` (menu entry) → `LibraryView.lua` (browse library) → `ChapterListing.lua` (chapters + download) → `MangaReader.lua` (open CBZ in KOReader's reader)

`Backend.lua` is the HTTP client. All server communication goes through it.

## Local Contracts

- Server URL stored in `DataStorage:getSettingsDir() .. "/komikku.lua"`
- Downloaded pages cached in `DataStorage:getDataDir() .. "/komikku_cache/"`
- CBZ files assembled via system `zip` command; falls back to opening first image if `zip` unavailable
- Page images always fetched through server proxy (`/api/v1/image?url=&sourceId=`) to preserve source auth headers

## Work Guidance

- Follow KOReader plugin conventions (CamelCase module names, `InputContainer:extend` pattern)
- Use `Trapper:wrap()` for any blocking HTTP operations
- Use `_ = require("gettext")` for translatable strings
- EmmyLua annotations on public APIs
