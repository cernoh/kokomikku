package eu.kanade.tachiyomi.data.server

import android.content.Context
import eu.kanade.tachiyomi.data.cache.ChapterCache
import eu.kanade.tachiyomi.data.cache.CoverCache
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.online.HttpSource
import fi.iki.elonen.NanoHTTPD
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import tachiyomi.domain.chapter.model.Chapter
import tachiyomi.domain.chapter.repository.ChapterRepository
import tachiyomi.domain.history.model.HistoryUpdate
import tachiyomi.domain.history.repository.HistoryRepository
import tachiyomi.domain.manga.model.Manga
import tachiyomi.domain.manga.repository.MangaRepository
import tachiyomi.domain.source.service.SourceManager
import timber.log.Timber
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.get
import java.io.ByteArrayInputStream
import java.io.FileInputStream
import java.util.Date

/**
 * Embedded HTTP server for KOReader communication over WiFi.
 * Exposes a JSON REST API for browsing the library, reading chapters,
 * and tracking progress.
 *
 * Endpoints:
 * - GET  /                            Health check
 * - GET  /api/v1/library              List favorite manga
 * - GET  /api/v1/manga/{id}           Manga details
 * - GET  /api/v1/manga/{id}/chapters  Chapters for a manga
 * - GET  /api/v1/manga/{id}/cover     Cover image bytes
 * - GET  /api/v1/chapter/{id}/pages   Page list for a chapter
 * - GET  /api/v1/image?url=&sourceId= Proxy a page image through the source
 * - POST /api/v1/chapter/{id}/progress Update reading progress
 * - GET  /api/v1/sources              Installed sources
 */
class KomikkuHttpServer(
    private val context: Context,
    private val port: Int = 8080,
) : NanoHTTPD(port) {

    private val mangaRepository: MangaRepository = Injekt.get()
    private val chapterRepository: ChapterRepository = Injekt.get()
    private val historyRepository: HistoryRepository = Injekt.get()
    private val sourceManager: SourceManager = Injekt.get()
    private val chapterCache: ChapterCache = Injekt.get()
    private val coverCache: CoverCache = Injekt.get()

    private val json = Json {
        prettyPrint = true
        encodeDefaults = true
        explicitNulls = false
    }

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri
        val method = session.method

        return try {
            when {
                uri == "/" -> jsonResponse(Status.OK, """{"status":"ok","name":"komikku"}""")

                uri == "/api/v1/library" -> serveLibrary()
                uri.matches(MANGA_ID_REGEX) -> serveMangaDetails(uri)
                uri.matches(MANGA_CHAPTERS_REGEX) -> serveChapters(uri)
                uri.matches(MANGA_COVER_REGEX) -> serveCover(uri)
                uri.matches(CHAPTER_PAGES_REGEX) -> servePages(uri)
                uri == "/api/v1/image" && method == Method.GET -> serveImage(session)
                uri.matches(CHAPTER_PROGRESS_REGEX) && method == Method.POST ->
                    serveProgressUpdate(uri, session)
                uri == "/api/v1/sources" -> serveSources()

                else -> jsonResponse(Status.NOT_FOUND, """{"error":"not found"}""")
            }
        } catch (e: Exception) {
            Timber.tag(TAG).e(e, "Error serving $uri")
            jsonResponse(
                Status.INTERNAL_ERROR,
                """{"error":"${e.message?.replace("\"", "\\\"") ?: "internal error"}"}""",
            )
        }
    }

    // --- Library ---

    private fun serveLibrary(): Response = runBlocking {
        val favorites = mangaRepository.getFavorites()
        val response = favorites.map { it.toApiResponse() }
        jsonResponse(Status.OK, json.encodeToString(response))
    }

    // --- Manga details ---

    private fun serveMangaDetails(uri: String): Response = runBlocking {
        val mangaId = extractId(uri, 4)
        val manga = mangaRepository.getMangaById(mangaId)
        jsonResponse(Status.OK, json.encodeToString(manga.toApiResponse()))
    }

    // --- Chapters ---

    private fun serveChapters(uri: String): Response = runBlocking {
        // URI: /api/v1/manga/{mangaId}/chapters
        val mangaId = extractId(uri, 4)
        val chapters = chapterRepository.getChapterByMangaId(mangaId)
        val response = chapters.map { it.toApiResponse() }
        jsonResponse(Status.OK, json.encodeToString(response))
    }

    // --- Cover image ---

    private fun serveCover(uri: String): Response = runBlocking {
        val mangaId = extractId(uri, 4)
        val manga = mangaRepository.getMangaById(mangaId)

        // Try custom cover first, then thumbnail cache
        val customCover = coverCache.getCustomCoverFile(mangaId)
        if (customCover.exists()) {
            return@runBlocking newChunkedResponse(
                Status.OK, guessMimeType(customCover), FileInputStream(customCover),
            )
        }

        val coverFile = coverCache.getCoverFile(manga.thumbnailUrl)
        if (coverFile != null && coverFile.exists()) {
            return@runBlocking newChunkedResponse(
                Status.OK, guessMimeType(coverFile), FileInputStream(coverFile),
            )
        }

        jsonResponse(Status.NOT_FOUND, """{"error":"cover not cached"}""")
    }

    // --- Pages ---

    private fun servePages(uri: String): Response = runBlocking {
        // URI: /api/v1/chapter/{chapterId}/pages
        val chapterId = extractId(uri, 4)
        val chapter = chapterRepository.getChapterById(chapterId)
            ?: return@runBlocking jsonResponse(Status.NOT_FOUND, """{"error":"chapter not found"}""")

        val manga = mangaRepository.getMangaById(chapter.mangaId)
        val source = sourceManager.get(manga.source) as? HttpSource
            ?: return@runBlocking jsonResponse(
                Status.BAD_REQUEST,
                """{"error":"source not available for this manga"}""",
            )

        // Try cache first, then fetch from source
        val pages = try {
            chapterCache.getPageListFromCache(chapter)
        } catch (_: Exception) {
            try {
                source.getPageList(chapter)
            } catch (e: Exception) {
                return@runBlocking jsonResponse(
                    Status.INTERNAL_ERROR,
                    """{"error":"failed to fetch pages: ${e.message?.replace("\"", "\\\"")}"}""",
                )
            }
        }

        // Cache the page list
        try {
            chapterCache.putPageListToCache(chapter, pages)
        } catch (_: Exception) { /* ignore */ }

        val response = pages.map { page ->
            PageResponse(
                index = page.index,
                imageUrl = page.imageUrl ?: "",
                url = page.url,
            )
        }
        jsonResponse(Status.OK, json.encodeToString(response))
    }

    // --- Image proxy ---
    // Proxies a page image through the server so the client doesn't need
    // source-specific headers. Query params: url (image URL), sourceId (source key).

    private fun serveImage(session: IHTTPSession): Response {
        val imageUrl = session.parms["url"]
            ?: return jsonResponse(Status.BAD_REQUEST, """{"error":"missing url parameter"}""")
        val sourceId = session.parms["sourceId"]?.toLongOrNull()
            ?: return jsonResponse(Status.BAD_REQUEST, """{"error":"missing sourceId parameter"}""")

        // Check cache first
        if (chapterCache.isImageInCache(imageUrl)) {
            val file = chapterCache.getImageFile(imageUrl)
            if (file.exists()) {
                return newChunkedResponse(Status.OK, guessMimeType(file), FileInputStream(file))
            }
        }

        // Fetch via source with proper headers
        val source = sourceManager.get(sourceId) as? HttpSource
            ?: return jsonResponse(Status.NOT_FOUND, """{"error":"source not found"}""")

        return try {
            val page = Page(0, imageUrl = imageUrl)
            val okHttpResponse = source.getImage(page)
            val bytes = okHttpResponse.body?.bytes()
                ?: return jsonResponse(Status.INTERNAL_ERROR, """{"error":"empty response from source"}""")

            // Write to cache manually (body already consumed)
            try {
                val cacheFile = chapterCache.getImageFile(imageUrl)
                cacheFile.writeBytes(bytes)
            } catch (_: Exception) { /* ignore cache write failures */ }

            val mimeType = guessMimeTypeFromUrl(imageUrl)
            newChunkedResponse(Status.OK, mimeType, ByteArrayInputStream(bytes))
        } catch (e: Exception) {
            Timber.tag(TAG).e(e, "Failed to fetch image: $imageUrl")
            jsonResponse(
                Status.INTERNAL_ERROR,
                """{"error":"failed to fetch image: ${e.message?.replace("\"", "\\\"")}"}""",
            )
        }
    }

    // --- Progress ---

    private fun serveProgressUpdate(uri: String, session: IHTTPSession): Response {
        val chapterId = extractId(uri, 4)

        val bodyMap = mutableMapOf<String, String>()
        session.parseBody(bodyMap)
        val postData = bodyMap["postData"] ?: "{}"

        val parsed = try {
            json.decodeFromString<ProgressRequest>(postData)
        } catch (_: Exception) {
            return jsonResponse(Status.BAD_REQUEST, """{"error":"invalid request body"}""")
        }

        runBlocking {
            historyRepository.upsertHistory(
                HistoryUpdate(
                    chapterId = chapterId,
                    readAt = Date(),
                    sessionReadDuration = parsed.readDuration ?: 0L,
                ),
            )
        }

        return jsonResponse(Status.OK, """{"status":"ok"}""")
    }

    // --- Sources ---

    private fun serveSources(): Response {
        val sources = sourceManager.getAll().map { source ->
            SourceResponse(
                id = source.id,
                name = source.name,
                lang = source.lang,
            )
        }
        return jsonResponse(Status.OK, json.encodeToString(sources))
    }

    // --- Helpers ---

    private fun jsonResponse(status: Status, body: String): Response {
        return newFixedLengthResponse(status, "application/json", body)
    }

    private fun extractId(uri: String, segmentIndex: Int): Long {
        return uri.split("/")[segmentIndex].toLong()
    }

    private fun guessMimeType(file: File): String {
        return when (file.extension.lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "avif" -> "image/avif"
            else -> "application/octet-stream"
        }
    }

    private fun guessMimeTypeFromUrl(url: String): String {
        val ext = url.substringAfterLast(".").substringBefore("?").lowercase()
        return when (ext) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "avif" -> "image/avif"
            else -> "image/jpeg" // fallback
        }
    }

    // --- Regex patterns for routing ---

    companion object {
        private const val TAG = "KomikkuHttpServer"
        private val MANGA_ID_REGEX = Regex("/api/v1/manga/\\d+")
        private val MANGA_CHAPTERS_REGEX = Regex("/api/v1/manga/\\d+/chapters")
        private val MANGA_COVER_REGEX = Regex("/api/v1/manga/\\d+/cover")
        private val CHAPTER_PAGES_REGEX = Regex("/api/v1/chapter/\\d+/pages")
        private val CHAPTER_PROGRESS_REGEX = Regex("/api/v1/chapter/\\d+/progress")
    }

    // --- Response models ---

    @Serializable
    data class MangaResponse(
        val id: Long,
        val sourceId: Long,
        val title: String,
        val author: String?,
        val artist: String?,
        val description: String?,
        val genre: List<String>?,
        val status: Long,
        val thumbnailUrl: String?,
        val favorite: Boolean,
        val dateAdded: Long,
        val lastUpdate: Long,
        val coverLastModified: Long,
    )

    @Serializable
    data class ChapterResponse(
        val id: Long,
        val mangaId: Long,
        val name: String,
        val url: String,
        val chapterNumber: Double,
        val scanlator: String?,
        val read: Boolean,
        val bookmark: Boolean,
        val dateUpload: Long,
        val lastPageRead: Long,
        val sourceOrder: Long,
    )

    @Serializable
    data class PageResponse(
        val index: Int,
        val imageUrl: String,
        val url: String,
    )

    @Serializable
    data class SourceResponse(
        val id: Long,
        val name: String,
        val lang: String,
    )

    @Serializable
    data class ProgressRequest(
        val readDuration: Long? = null,
    )

    // --- Mappers ---

    private fun Manga.toApiResponse() = MangaResponse(
        id = id,
        sourceId = source,
        title = title,
        author = author,
        artist = artist,
        description = description,
        genre = genre,
        status = status,
        thumbnailUrl = thumbnailUrl,
        favorite = favorite,
        dateAdded = dateAdded,
        lastUpdate = lastUpdate,
        coverLastModified = coverLastModified,
    )

    private fun Chapter.toApiResponse() = ChapterResponse(
        id = id,
        mangaId = mangaId,
        name = name,
        url = url,
        chapterNumber = chapterNumber,
        scanlator = scanlator,
        read = read,
        bookmark = bookmark,
        dateUpload = dateUpload,
        lastPageRead = lastPageRead,
        sourceOrder = sourceOrder,
    )
}
