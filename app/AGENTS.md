# app

Main Android application module. Contains UI screens, dependency injection, app lifecycle, all three source lineages (`eu.kanade`, `mihon`, `exh`), and the bridge between presentation/domain/data layers.

## Purpose

- Android `Application` class, DI wiring (`di/`), crash handling
- UI screens: library, manga detail, reader, updates, history, browse, settings, onboarding
- Source management: extension installer, online sources, local source bridge
- Data subsystems: downloads, library updates, sync, tracking, backup/export, database, notifications, push connections (Discord)
- App updater (`data/updater/`)

## Ownership

All changes that touch `eu.kanade.tachiyomi.*`, `mihon.*`, or `exh.*` under this module.

## Local Contracts

- DI uses Injekt. Modules live in `di/` (`AppModule.kt`, `PreferenceModule.kt`, `SYPreferenceModule.kt`). New bindings go in the closest matching module.
- UI screens use Compose. ScreenModels (state holders) sit next to their screens under `ui/<feature>/`.
- `// SY -->` / `// SY <--` and `// KMK -->` / `// KMK <--` blocks are upstream merge markers. Preserve them on edit; they survive rebases.
- `AndroidManifest.xml` declares all permissions, activities, services, and receivers. Add components here.

## Work Guidance

- New UI → new `ui/<feature>/` subpackage with a `Screen.kt` and `ScreenModel.kt`.
- New background work → `WorkManager` job in `data/` or a foreground service.
- New online source → implement in `source/online/`; see `source-api` module for the contract.
- Navigation → Voyager. Screen routes go through `ui/main/`.

## Verification

Build: `./gradlew :app:assembleDebug`
Unit tests: `./gradlew :app:testDebugUnitTest`

## Child DOX Index

None. All subpackages are covered by this module doc.
