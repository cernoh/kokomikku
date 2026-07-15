local http = require("socket.http")
local ltn12 = require("ltn12")
local socket = require("socket")
local socketutil = require("socketutil")
local rapidjson = require("rapidjson")
local logger = require("logger")

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

local SETTINGS_FILE = DataStorage:getSettingsDir() .. "/komikku.lua"

--- @class Backend
--- HTTP client for the Komikku Android app's HTTP server.
local Backend = {}

local settings = LuaSettings:open(SETTINGS_FILE)

--- Returns the configured server base URL (e.g. "http://192.168.1.100:8080").
--- @return string
function Backend.getBaseUrl()
    return settings:readSetting("server_url", "http://192.168.1.100:8080")
end

--- Saves the server URL to settings.
--- @param url string
function Backend.setBaseUrl(url)
    settings:saveSetting("server_url", url)
    settings:flush()
end

--- Performs a HTTP GET request and returns the parsed JSON response.
--- @generic T
--- @param path string The API path (e.g. "/api/v1/library")
--- @return { type: "SUCCESS", body: T }|{ type: "ERROR", status: number, message: string }
function Backend.requestJson(path)
    local url = Backend.getBaseUrl() .. path
    local sink = {}
    socketutil:set_timeout(30)
    local request = {
        url    = url,
        method = "GET",
        sink   = ltn12.sink.table(sink),
    }

    local code, headers, status = socket.skip(1, http.request(request))
    socketutil:reset_timeout()
    local content = table.concat(sink)

    if code == socketutil.TIMEOUT_CODE or
       code == socketutil.SSL_HANDSHAKE_CODE or
       code == socketutil.SINK_TIMEOUT_CODE then
        return { type = "ERROR", status = 0, message = "Request timed out" }
    end

    if not code or code < 200 or code > 299 then
        return { type = "ERROR", status = code or 0, message = status or "Network error" }
    end

    local ok, parsed = pcall(rapidjson.decode, content)
    if not ok then
        return { type = "ERROR", status = code, message = "Invalid JSON response" }
    end

    return { type = "SUCCESS", body = parsed }
end

--- Performs a HTTP POST request with JSON body.
--- @param path string The API path
--- @param body table The body to send as JSON
--- @return { type: "SUCCESS", body: any }|{ type: "ERROR", status: number, message: string }
function Backend.postJson(path, body)
    local url = Backend.getBaseUrl() .. path
    local json_body = rapidjson.encode(body)
    local sink = {}
    socketutil:set_timeout(30)
    local request = {
        url    = url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#json_body),
        },
        source = ltn12.source.string(json_body),
        sink   = ltn12.sink.table(sink),
    }

    local code, headers, status = socket.skip(1, http.request(request))
    socketutil:reset_timeout()
    local content = table.concat(sink)

    if not code or code < 200 or code > 299 then
        return { type = "ERROR", status = code or 0, message = status or "Network error" }
    end

    local ok, parsed = pcall(rapidjson.decode, content)
    if not ok then
        return { type = "SUCCESS", body = nil }
    end
    return { type = "SUCCESS", body = parsed }
end

--- Downloads a binary file from a URL and saves it to a local path.
--- @param url string
--- @param filepath string
--- @return boolean success
function Backend.downloadFile(url, filepath)
    local file = io.open(filepath, "wb")
    if not file then
        logger.warn("Cannot open file for writing:", filepath)
        return false
    end
    local sink = ltn12.sink.file(file)
    socketutil:set_timeout(60)
    local code, headers, status = socket.skip(1, http.request{
        url  = url,
        sink = sink,
    })
    socketutil:reset_timeout()

    if not code or code < 200 or code > 299 then
        logger.warn("Download failed:", url, status or code)
        return false
    end
    return true
end

-- API Methods

--- @class Manga
--- @field id number
--- @field sourceId number
--- @field title string
--- @field author string|nil
--- @field artist string|nil
--- @field description string|nil
--- @field genre string[]|nil
--- @field status number
--- @field thumbnailUrl string|nil
--- @field favorite boolean
--- @field dateAdded number
--- @field lastUpdate number
--- @field coverLastModified number

--- Fetches the user's library (favorite manga).
--- @return { type: string, body: Manga[] }|{ type: string, status: number, message: string }
function Backend.getLibrary()
    return Backend.requestJson("/api/v1/library")
end

--- @class Chapter
--- @field id number
--- @field mangaId number
--- @field name string
--- @field url string
--- @field chapterNumber number
--- @field scanlator string|nil
--- @field read boolean
--- @field bookmark boolean
--- @field dateUpload number
--- @field lastPageRead number
--- @field sourceOrder number

--- Fetches chapters for a given manga.
--- @param mangaId number
--- @return { type: string, body: Chapter[] }|{ type: string, status: number, message: string }
function Backend.getChapters(mangaId)
    return Backend.requestJson("/api/v1/manga/" .. mangaId .. "/chapters")
end

--- @class Page
--- @field index number
--- @field imageUrl string
--- @field url string

--- Fetches the page list for a chapter.
--- @param chapterId number
--- @return { type: string, body: Page[] }|{ type: string, status: number, message: string }
function Backend.getPages(chapterId)
    return Backend.requestJson("/api/v1/chapter/" .. chapterId .. "/pages")
end

--- Reports reading progress for a chapter.
--- @param chapterId number
--- @param readDuration number|nil
function Backend.reportProgress(chapterId, readDuration)
    return Backend.postJson("/api/v1/chapter/" .. chapterId .. "/progress", {
        readDuration = readDuration or 0,
    })
end

--- Returns a proxied image URL that goes through the Komikku server.
--- The server fetches the image with proper source headers.
--- @param imageUrl string The original image URL from the source
--- @param sourceId number The source ID for header resolution
--- @return string
function Backend.getProxyImageUrl(imageUrl, sourceId)
    -- URL-encode the image URL for use as a query parameter
    local encoded_url = imageUrl:gsub("([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return Backend.getBaseUrl() .. "/api/v1/image?url=" .. encoded_url .. "&sourceId=" .. tostring(sourceId)
end

--- Returns the URL for a manga's cover image.
--- @param mangaId number
--- @return string
function Backend.getCoverUrl(mangaId)
    return Backend.getBaseUrl() .. "/api/v1/manga/" .. mangaId .. "/cover"
end

--- Fetches the list of installed sources.
--- @return { type: string, body: { id: number, name: string, lang: string }[] }|{ type: string, status: number, message: string }
function Backend.getSources()
    return Backend.requestJson("/api/v1/sources")
end

--- Checks if the server is reachable.
--- @return boolean
function Backend.isServerReachable()
    local response = Backend.requestJson("/")
    return response.type == "SUCCESS"
end

return Backend
