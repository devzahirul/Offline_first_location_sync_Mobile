# rtls-kmp

Kotlin Multiplatform (Android-only) sync module for offline-first location sync. Implements the same contract as the Swift RTLSyncKit: local SQLite store, batch upload to the backend, sync engine with retry.

Used by the **Native Android app** and the **Flutter plugin** (Android side). Same backend: `POST /v1/locations/batch`, `GET /v1/locations/latest`, `WS /v1/ws`.

## Structure

- **commonMain:** Models (`LocationPoint`, `LocationUploadBatch`, etc.), `LocationStore`, `LocationSyncAPI`, `SyncEngine`, `LocationSyncClient`.
- **androidMain:** `SqliteLocationStore`, `OkHttpLocationSyncAPI`, `AndroidLocationProvider`, `RTLSKmp` factory.

## Build

From this directory (or from a parent that includes this project):

```bash
./gradlew :rtls-kmp:assembleDebug
```

Or include in a host app's `settings.gradle.kts`:

```kotlin
include(":rtls-kmp")
project(":rtls-kmp").projectDir = file("../rtls-kmp")
```

## Usage

From Android (or Flutter plugin Android):

```kotlin
val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
val client = RTLSKmp.createLocationSyncClient(
    context, baseUrl, userId, deviceId, accessToken, scope
)
val locationFlow = RTLSKmp.createLocationFlow(context, userId, deviceId)
client.startCollectingLocation(locationFlow)
// later: client.stopTracking(), client.stats(), client.flushNow()
client.events.collect { event -> ... }
```
