# domain

Business logic layer. Pure Kotlin where possible. No Android framework imports, no I/O.

## Purpose

- Use cases (interactors) for manga, chapter, library, downloads, tracking, updates, extensions, sources
- Repository interfaces (contracts the `data` module implements)
- Domain models: `Manga`, `Chapter`, `Category`, `Track`, `Download`, etc.
- Sync manager (orchestrates sync protocol, delegates I/O to data layer via interfaces)
- Base preferences interfaces

## Ownership

All business rules. If it's a decision about *what* the app does (not *how* it stores or shows it), it belongs here.

## Local Contracts

- Repository interfaces are the only way to reach the data layer. Use cases depend on interfaces, not implementations.
- Domain models are data classes. Keep them framework-free (no Room, no SQLDelight, no OkHttp types).
- Use cases are single-responsibility. One class, one `await()` or `subscribe()` entry point.
- DI bindings for domain live in `app/di/`; this module doesn't wire its own.

## Work Guidance

- New business rule → add a use case class.
- New data need → add a repository interface here, implement in `data`.
- Domain models should not import from `data` or `presentation`.

## Verification

Build: `./gradlew :domain:build`
Unit tests: `./gradlew :domain:test`

## Child DOX Index

None. Single module, covered here.
