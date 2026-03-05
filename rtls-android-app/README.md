# RTLS Native Android App

**Reference Android client** for the Real-Time Location Sync backend. Standalone Kotlin app that consumes the modular rtls-kmp library (five independent Gradle submodules)—single Activity, ViewBinding, FusedLocationProvider/LocationManager fallback, and a minimal config + status UI.

---

## Architecture

Single-Activity app that depends on the multi-module `rtls-kmp` structure. Each capability lives in its own Gradle module:

| Module | What it provides |
|--------|-----------------|
| `rtls-core` | Models, interfaces, policies |
| `rtls-offline-sync` | SyncEngine, SqliteLocationStore, OkHttpLocationSyncAPI, OfflineSyncClient |
| `rtls-websocket` | RealTimeLocationClient, OkHttpRealTimeChannel, auto-reconnect |
| `rtls-location` | AndroidLocationProvider, LocationRecordingDecider, AndroidNetworkMonitor |
| `rtls-client` | RTLSClient orchestrator, RTLSClientFactory Builder |

The app depends on `rtls-client`, which transitively pulls in all other modules. The KMP library owns persistence (SQLite), batching, retry, retention, WebSocket streaming, and network gating; the app wires the `RTLSClient` to a simple config + status UI.

| Layer | Responsibility |
|-------|----------------|
| **MainActivity** | Config (baseUrl, userId, deviceId, token), Start/Stop, Flush Now, permission flow, event collection via `SharedFlow` |
| **LocationSyncClient** | Consumes `Flow<LocationPoint>`, inserts into store, notifies `SyncEngine`, exposes `events: SharedFlow<LocationSyncClientEvent>` |
| **SyncEngine** | Mutex-serialized flush loop; `BatchingPolicy` (batch size, interval, max age), `SyncRetryPolicy` (exponential backoff), `RetentionPolicy` (sent-point pruning), `AndroidNetworkMonitor` (online gate) |
| **AndroidLocationProvider** | `FusedLocationProviderClient` on API 28+, `LocationManager` fallback on API ≤28 |

---

## Features

- **Config:** baseUrl, userId, deviceId, token—applied once via Configure; used to instantiate `RTLSClientFactory.Builder(context).…build()`.
- **Tracking:** Start/Stop; location flow built via `RTLSClientFactory`, fed into `RTLSClient.startCollectingLocation()`.
- **Flush:** "Flush now" calls `client.flushNow()` for immediate upload within engine policy.
- **Status:** Pending count and last event from `client.stats()` and `client.events`.
- **Permissions:** Runtime request for `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` (Android 10+); requested before tracking.

**Event stream (`LocationSyncClient.events`):** `Recorded`, `SyncEvent` (wraps `UploadSuccess(accepted, rejected)` / `UploadFailed(message)`), `Error`, `TrackingStarted`, `TrackingStopped`.

---

## Build & Run

**Prerequisites:** Android SDK (API 21+). The `rtls-kmp` directory (containing all five submodules) must be a sibling directory (`../rtls-kmp`) or paths adjusted in `settings.gradle.kts`.

```bash
cd rtls-android-app
./gradlew assembleDebug
./gradlew installDebug
```

Or open in Android Studio and run the `app` configuration.

**First run:** Configure baseUrl (e.g. `http://10.0.2.2:3000` for emulator), userId, deviceId, token → grant location permissions → Start tracking → Flush Now for immediate upload. Pending count and last event update from the event stream.

---

## Integration Notes

- **Subproject dependencies:** The app's `settings.gradle.kts` includes individual modules from `../rtls-kmp/`:

  ```kotlin
  include(":rtls-core")
  include(":rtls-offline-sync")
  include(":rtls-websocket")
  include(":rtls-location")
  include(":rtls-client")

  project(":rtls-core").projectDir = file("../rtls-kmp/rtls-core")
  project(":rtls-offline-sync").projectDir = file("../rtls-kmp/rtls-offline-sync")
  project(":rtls-websocket").projectDir = file("../rtls-kmp/rtls-websocket")
  project(":rtls-location").projectDir = file("../rtls-kmp/rtls-location")
  project(":rtls-client").projectDir = file("../rtls-kmp/rtls-client")
  ```

  **app/build.gradle.kts:** `implementation(project(":rtls-client"))` (pulls all modules transitively). For a lighter build, depend only on the specific modules you need (e.g., `":rtls-offline-sync"`).
- **Backend:** Same API as iOS/Flutter: `POST /v1/locations/batch` (Bearer token). Emulator: `http://10.0.2.2:3000`; physical device: host LAN IP, backend on `0.0.0.0`.
- **Min SDK 21, target 34.**

---

## License

See repository [LICENSE](../LICENSE).
