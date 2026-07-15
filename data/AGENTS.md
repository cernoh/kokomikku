# data

Data access layer. Owns all I/O: database (SQLDelight), network (OkHttp), disk (file storage, downloads, backups), and preferences.

## Purpose

- Repository implementations (implementing interfaces from `domain`)
- SQLDelight schema and queries (`src/main/sqldelight/`)
- Network layer: API clients for trackers (Anilist, MAL, Kitsu, Bangumi, Shikimori, MangaUpdates, Komga, Suwayomi), sync services (Google Drive, SyncYomi)
- Download manager, library update scheduler, backup/restore, export
- Discord Rich Presence connection
- Embedded HTTP server for KOReader communication over WiFi (`data/server/`)
- App updater (fetches APK updates from GitHub)

## Ownership

All persistence and external communication. The `domain` module defines *what* the data layer provides; this module defines *how*.

## Local Contracts

- Repository classes implement interfaces declared in `domain`. Never expose SQLDelight types or OkHttp types above this layer.
- Database migrations go in SQLDelight `.sq` migration files (`src/main/sqldelight/`).
- Network clients use OkHttp. Response parsing uses kotlinx.serialization.
- Preferences are abstracted via `core/common` preference store; concrete implementations live here.

## Work Guidance

- New data source → add repository interface in `domain`, implementation here.
- New tracker → add API client under `data/track/<name>/`, wire into `TrackService` in domain.
- Database schema change → write SQLDelight migration, update affected repository.

## Verification

Build: `./gradlew :data:build`
Unit tests: `./gradlew :data:testDebugUnitTest`

## Child DOX Index

None. Single module, covered here.
