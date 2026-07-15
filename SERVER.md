# Komikku HTTP Server for KOReader

## Overview
Embedded HTTP server that allows KOReader to browse and read manga from the Komikku library over WiFi.

## Architecture
- **NanoHTTPD** - Lightweight embedded HTTP server (port 8080)
- **OPDS Protocol** - Open Publication Distribution System for catalog browsing
- **Foreground Service** - Keeps server running in background

## Implementation Status
✅ HTTP server class with OPDS endpoints (skeleton with mock data)
✅ Foreground service to host server
✅ Notification channel and constants
✅ Service registration in manifest
✅ String resources for all UI elements
✅ Preference for server state tracking
✅ **Settings UI toggle with Material You theming** - fully integrated into Connections settings page

## Files Created/Modified
- `app/src/main/java/eu/kanade/tachiyomi/data/server/KomikkuHttpServer.kt` - HTTP server implementation
- `app/src/main/java/eu/kanade/tachiyomi/data/server/KomikkuHttpService.kt` - Foreground service
- `gradle/libs.versions.toml` - Added NanoHTTPD dependency
- `app/build.gradle.kts` - Added NanoHTTPD to dependencies
- `app/src/main/AndroidManifest.xml` - Registered service
- `app/src/main/java/eu/kanade/tachiyomi/data/notification/Notifications.kt` - Added notification constants
- `i18n-kmk/src/commonMain/moko-resources/base/strings.xml` - Added string resources
- `app/src/main/java/eu/kanade/domain/connections/service/ConnectionsPreferences.kt` - Added preference
- **`app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsConnectionScreen.kt`** - Added UI toggle
## Endpoints
- `GET /` - Simple HTML status page
- `GET /opds` - OPDS root catalog
- `GET /opds/manga` - Manga library listing
- `GET /opds/manga/{id}` - Manga details with chapters
- `GET /image/{path}` - Page images (TODO: implement)

## TODO
- [ ] Query actual manga library from database (currently returns mock data)
- [ ] Implement chapter listing endpoint
- [ ] Serve actual page images from local storage/cache
- [ ] Add UI toggle to start/stop server (settings menu)
- [ ] Add server status indicator in UI
- [ ] Implement authentication (optional, for security)
- [ ] Test with actual KOReader device

## Usage
### Start Server
```kotlin
KomikkuHttpService.startService(context)
```

### Stop Server
```kotlin
KomikkuHttpService.stopService(context)
```

### KOReader Configuration
1. Open KOReader on your e-reader device
2. Go to Settings → OPDS catalog
3. Add new catalog:
   - Title: `Komikku`
   - URL: `http://<android-device-ip>:8080/opds`
4. Browse and download manga

### Find Device IP
The server notification displays the IP address and port when running.

## Testing
1. Install the app on an Android device
2. Start the HTTP server (via code or UI toggle)
3. Note the IP address shown in the notification
4. From another device on the same WiFi, open a browser to `http://<ip>:8080`
5. Verify the status page loads
6. Test `/opds` endpoint for catalog XML

## Security Notes
- Currently no authentication - anyone on the WiFi network can access
- Consider adding basic auth or token-based auth for production use
- Server binds to all interfaces (0.0.0.0) - change to localhost for security if needed
