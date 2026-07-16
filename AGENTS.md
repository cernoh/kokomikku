# kokomikku

Android manga reader. Fork of [Komikku](https://github.com/komikku-app/komikku) (itself a Mihon/Tachiyomi descendant) that adds an HTTP server so KOReader can talk to it. The server is the fork's purpose; everything else is upstream Komikku carried forward.

## Language & Stack

- Kotlin, Android SDK, Jetpack Compose
- Gradle (Kotlin DSL) with version catalogs under `gradle/`
- SQLDelight for persistence, OkHttp for networking, Coil for images, Voyager for navigation, Injekt for DI, Jsoup for HTML parsing
- Upstream modifications from TachiyomiSY (SY) and Komikku (KMK) are marked inline with `// SY -->` / `// SY <--` and `// KMK -->` / `// KMK <--` comment pairs

## Architecture

Clean architecture with strict layer boundaries:

- **presentation** — Compose UI screens, ScreenModels, theme. Thin; no business logic.
- **domain** — Use cases, business rules, repository interfaces. Pure Kotlin where possible.
- **data** — Repository implementations, SQLDelight database, network calls, disk I/O.

Dependency flow: `presentation → domain ← data`. Data and presentation never import each other directly; domain interfaces are the contract.

## Code Lineages (app module)

Three source lineages coexist under `app/src/main/java/`:

| Package | Origin | Scope |
|---------|--------|-------|
| `eu.kanade.tachiyomi` | Tachiyomi upstream | Core app: data, domain, presentation, sources, DI |
| `mihon` | Mihon fork | Migration framework, design system, Shizuku integration |
| `exh` | TachiyomiSY fork | EHentai/MangaDex extras, enhanced logging, recommendations, smart search |

## Build Variants

`debug`, `release`, `preview` (beta), `foss`, `benchmark`, `releaseTest`. Application ID: `app.kokomikku`.

## Conventions

- New code follows existing patterns in the target module before inventing new ones.
- SY/KMK tagged blocks are upstream merges; treat them as read-only unless rebasing.
- Compose UI lives in `presentation/` subpackages; keep screen composition in presentation, state in ScreenModels.
- Database changes go through SQLDelight `.sq` files in `data/src/main/sqldelight/`.
- Tests use JUnit 5 + Kotest assertions + MockK.

## Child DOX Index

| Path | Scope |
|------|-------|
| [`app/AGENTS.md`](app/AGENTS.md) | Main application module: UI, DI, lifecycle, all three lineages |
| [`core/AGENTS.md`](core/AGENTS.md) | `core/common` (shared utilities, multiplatform) and `core/archive` (CBZ/CBR/archive handling) |
| [`data/AGENTS.md`](data/AGENTS.md) | Data layer: repositories, SQLDelight, network, preferences |
| [`domain/AGENTS.md`](domain/AGENTS.md) | Domain layer: use cases, business logic, repository interfaces |
| [`source-api/AGENTS.md`](source-api/AGENTS.md) | Source/extension API: the contract manga sources implement |
| [`presentation-core/AGENTS.md`](presentation-core/AGENTS.md) | Shared Compose UI components and theming |
| [`komikku.koplugin/AGENTS.md`](komikku.koplugin/AGENTS.md) | KOReader plugin: Lua frontend for browsing/reading manga over WiFi |

Thin modules without their own DOX — covered by this root: `core-metadata`, `source-local`, `presentation-widget`, `i18n`, `i18n-kmk`, `i18n-sy`, `flagkit`, `telemetry`, `macrobenchmark`, `buildSrc`, `gradle/`.
