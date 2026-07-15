# source-api

The contract that all manga sources (extensions) implement. Multiplatform (commonMain + androidMain).

## Purpose

- `SManga`, `SMangaInit`, `SChapter`, `Page`, `MangaSource` — the core data types sources return
- `OnlineSource`, `CatalogueSource`, `ConfigurableSource` — source capability interfaces
- `MangaSyncService` — tracker interface (Anilist, MAL, etc.)
- `SourceFactory` — extension entry point

## Ownership

The API surface that extension authors code against. Changes here ripple to every extension.

## Local Contracts

- Breaking changes to source interfaces require a version bump and migration guide.
- Prefer additive changes (new optional methods) over breaking ones.
- Source implementations live in separate extension APKs, not in this repo. This module only defines the contract.
- `exh` package (`exh/source/`, `exh/metadata/`, `exh/md/`) adds TachiyomiSY source extensions: MangaDex handlers, metadata enrichers.

## Work Guidance

- New source capability → add interface or extend existing one.
- New metadata field → add to the relevant data class with a default value for backward compat.

## Verification

Build: `./gradlew :source-api:build`

## Child DOX Index

None. Single module, covered here.
