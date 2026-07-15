# presentation-core

Shared Jetpack Compose UI components and theming. Used by `app` for all screens.

## Purpose

- Reusable Compose components: lists, cards, dialogs, preference screens, theme system
- Material 3 theming with dynamic color support
- Common layout primitives and navigation helpers
- `tachiyomi.presentation.*` and `mihon.presentation.*` packages

## Ownership

Any UI component used by more than one screen in the app. Screen-specific UI stays in `app/ui/<feature>/`.

## Local Contracts

- Compose only. No XML layouts (except legacy widget support in `presentation-widget`).
- Theme access through the composition local. Don't hardcode colors or typography.
- Components should be stateless where possible; state belongs in ScreenModels.

## Work Guidance

- New shared component → add here under the appropriate subpackage.
- Theme change → update the theme system; verify light/dark/dynamic color.

## Verification

Build: `./gradlew :presentation-core:build`

## Child DOX Index

None. Single module, covered here.
