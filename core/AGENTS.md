# core

Shared foundational modules. Kotlin Multiplatform where possible (commonMain + androidMain).

## Submodules

- **`core/common/`** — Utilities used across the project: extensions, preference abstractions, system helpers, language utilities, storage helpers, image utilities. Contains `tachiyomi.core.*` and `mihon.core.*` packages.
- **`core/archive/`** — Archive format handling (CBZ, CBR, etc.) for local source and downloads. Built on `libarchive`.

## Ownership

Cross-cutting changes that don't belong in a single layer. If something is needed by both `data` and `presentation`, it lives here.

## Local Contracts

- Multiplatform code goes in `commonMain/`; Android-specific in `androidMain/`.
- No dependency on `domain`, `data`, or `presentation`. This is a leaf module.
- Keep utilities small and self-contained. Don't pull in heavy dependencies.

## Work Guidance

- New shared utility → add to `core/common/` first.
- Archive format support → `core/archive/`.
- If a utility grows domain-specific, move it to the domain module instead.

## Verification

Build: `./gradlew :core:common:build :core:archive:build`

## Child DOX Index

None. Two submodules are small enough to be covered here.
