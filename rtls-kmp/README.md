# rtls-kmp — Modular Android Location Sync Engine

Kotlin Multiplatform library (Android target) split into five independent Gradle modules. Pick only the capabilities you need — offline sync, real-time WebSocket streaming, GPS collection, or all three via the orchestrator. Each module depends only on `rtls-core` and nothing else, so your APK ships exactly the code it uses.

---

## Module Overview

| Module | Package | Depends on | Purpose |
|--------|---------|------------|---------|
| **rtls-core** | `com.rtls.core` | — | Models (`LocationPoint`, `GeoCoordinate`), interfaces (`LocationStore`, `LocationSyncAPI`, `NetworkMonitor`), policies (`BatchingPolicy`, `SyncRetryPolicy`, `RetentionPolicy`) |
| **rtls-offline-sync** | `com.rtls.sync` | rtls-core | `SyncEngine`, `SqliteLocationStore`, `OkHttpLocationSyncAPI`, `OfflineSyncClient` — batched HTTP upload with exponential backoff, bidirectional pull/merge |
| **rtls-websocket** | `com.rtls.websocket` | rtls-core | `RealTimeLocationClient`, `OkHttpRealTimeChannel` — WebSocket protocol messages, auto-reconnect, push/subscribe |
| **rtls-location** | `com.rtls.location` | rtls-core | `AndroidLocationProvider`, `LocationRecordingDecider`, `AndroidNetworkMonitor` — GPS via FusedLocationProvider / LocationManager fallback |
| **rtls-client** | `com.rtls.client` | rtls-core, rtls-offline-sync, rtls-websocket, rtls-location | `RTLSClient` orchestrator, `RTLSClientFactory` with Builder pattern — wires everything together |

---

## Dependency Graph

```
                    ┌──────────────┐
                    │  rtls-core   │
                    │ (com.rtls.   │
                    │   core)      │
                    └──────┬───────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
┌─────────────────┐ ┌────────────┐ ┌───────────────┐
│ rtls-offline-   │ │  rtls-     │ │ rtls-location │
│ sync            │ │  websocket │ │               │
│ (com.rtls.sync) │ │ (com.rtls. │ │ (com.rtls.    │
│                 │ │  websocket)│ │  location)    │
└────────┬────────┘ └─────┬──────┘ └───────┬───────┘
         │                │                │
         └────────────────┼────────────────┘
                          │
                   ┌──────▼───────┐
                   │ rtls-client  │
                   │ (com.rtls.   │
                   │  client)     │
                   └──────────────┘
```

`rtls-client` is the only module that pulls in all four siblings. If you only need offline sync, depend on `rtls-offline-sync` alone — you get `rtls-core` transitively and nothing else.

---

## Quick Start

### a) Offline sync only (no GPS, no WebSocket)

**Gradle:** `implementation(project(":rtls-offline-sync"))`

```kotlin
val store = SqliteLocationStore(context)
val api = OkHttpLocationSyncAPI(baseUrl, tokenProvider)
val sync = OfflineSyncClient(store, api)
sync.start()
sync.insert(listOf(point1, point2))
```

### b) WebSocket only (real-time push/subscribe)

**Gradle:** `implementation(project(":rtls-websocket"))`

```kotlin
val ws = RealTimeLocationClient(config, OkHttpRealTimeChannel())
ws.connect()
ws.pushLocation(point)
ws.subscribe("user-id")
ws.incomingLocations.collect { ... }
```

### c) GPS + offline sync + WebSocket (full stack)

**Gradle:** `implementation(project(":rtls-client"))`

```kotlin
val client = RTLSClientFactory.Builder(context)
    .baseUrl("https://api.example.com")
    .userId("user123").deviceId("device456").accessToken("jwt")
    .offlineSync()
    .webSocket()
    .location()
    .build()
val flow = builder.buildLocationFlow()
client.startCollectingLocation(flow)
```

---

## Module Details

### rtls-core

Zero external dependencies beyond `kotlinx-coroutines` and `kotlinx-serialization`. Defines every interface and data type that the other modules program against.

**Key types:**

- `LocationPoint`, `GeoCoordinate`, `LocationUploadBatch`, `LocationUploadResult`, `RejectedPoint`
- `LocationStore` — insert, fetchPending, markSent, markFailed
- `SentPointsPrunableLocationStore` — extends `LocationStore` with `pruneSentPoints`
- `LocationSyncAPI` — `upload(batch) → Result`
- `NetworkMonitor` — `isOnline()`, `onlineFlow`
- `BatchingPolicy`, `SyncRetryPolicy`, `RetentionPolicy`

### rtls-offline-sync

Implements offline-first batched upload: GPS → SQLite → HTTP with exponential backoff, network gating, and configurable retention pruning.

**Key types:**

- `SqliteLocationStore` — raw Android SQLite; `INSERT OR REPLACE`, index on `sent_at IS NULL`
- `OkHttpLocationSyncAPI` — `POST /v1/locations/batch`, Bearer token auth, `kotlinx.serialization` JSON
- `SyncEngine` — mutex-serialized flush loop, timer job, network-online job, backoff, retention pruning
- `OfflineSyncClient` — high-level facade: `start()`, `stop()`, `insert()`, `flushNow()`, `stats()`

**Flush triggers:** timer tick (default 10s) · network comes online · new data inserted · manual `flushNow()`.

**Backoff:** `min(maxDelayMs, baseDelayMs · 2^(attempt-1)) ± jitter`. Resets on success. Transport errors never mark points as failed — only explicit server rejections do.

**Retention pruning:** deletes sent points older than `RetentionPolicy.sentPointsMaxAgeMs` (default 7 days), runs at most once per hour after a successful upload.

### rtls-websocket

Provides real-time bidirectional location streaming over WebSocket.

**Key types:**

- `RealTimeLocationClient` — connect, disconnect, pushLocation, subscribe/unsubscribe, `incomingLocations: Flow`
- `OkHttpRealTimeChannel` — OkHttp WebSocket transport with auto-reconnect and exponential backoff
- Protocol message types for push, subscribe, and server-sent location updates

### rtls-location

Android GPS collection with automatic API-level adaptation.

**Key types:**

- `AndroidLocationProvider` — `FusedLocationProviderClient` (API >= 29) with `LocationManager` fallback (API <= 28); `callbackFlow` emission; `getLastKnownLocation` for immediate first fix
- `LocationRecordingDecider` — filters duplicate / low-accuracy points before storage
- `AndroidNetworkMonitor` — `ConnectivityManager.registerDefaultNetworkCallback` → `callbackFlow` for reactive online/offline transitions

### rtls-client

Orchestrator that wires offline sync, WebSocket, and location collection into a single facade.

**Key types:**

- `RTLSClient` — `startCollectingLocation(Flow<LocationPoint>)`, `stopTracking()`, `stats()`, `flushNow()`, `events: SharedFlow`
- `RTLSClientFactory` — Builder pattern: `.offlineSync()`, `.webSocket()`, `.location()`, `.build()`

---

## Gradle Dependency Instructions

### As subproject (monorepo)

**settings.gradle.kts** (host project):

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

**app/build.gradle.kts** — pick only the modules you need:

```kotlin
dependencies {
    // Full stack:
    implementation(project(":rtls-client"))

    // Or pick individual modules:
    // implementation(project(":rtls-offline-sync"))
    // implementation(project(":rtls-websocket"))
    // implementation(project(":rtls-location"))
}
```

`rtls-core` is pulled in transitively by every module — no need to declare it explicitly.

---

## Migration Guide (from monolithic rtls-kmp)

The old monolithic structure exposed everything through a single `implementation(project(":rtls-kmp"))` dependency and the `RTLSKmp` factory object.

### What changed

| Before (monolithic) | After (modular) |
|---------------------|-----------------|
| Single `:rtls-kmp` Gradle module | Five modules: `:rtls-core`, `:rtls-offline-sync`, `:rtls-websocket`, `:rtls-location`, `:rtls-client` |
| `RTLSKmp.createLocationSyncClient()` | `RTLSClientFactory.Builder(context).…build()` |
| `RTLSKmp.createLocationFlow()` | `builder.buildLocationFlow()` via `RTLSClientFactory` |
| All classes in one package | Split across `com.rtls.core`, `com.rtls.sync`, `com.rtls.websocket`, `com.rtls.location`, `com.rtls.client` |

### Steps

1. **Update `settings.gradle.kts`** — replace `include(":rtls-kmp")` with the five module includes (see Gradle instructions above).

2. **Update `build.gradle.kts` dependency** — replace `implementation(project(":rtls-kmp"))` with either `implementation(project(":rtls-client"))` (full stack) or the specific modules you need.

3. **Fix imports** — update `import` statements to the new packages:
   - `com.rtls.kmp.*` → `com.rtls.core.*` for models/interfaces/policies
   - `com.rtls.kmp.*` → `com.rtls.sync.*` for `SqliteLocationStore`, `OkHttpLocationSyncAPI`, `SyncEngine`, `OfflineSyncClient`
   - `com.rtls.kmp.*` → `com.rtls.websocket.*` for `RealTimeLocationClient`, `OkHttpRealTimeChannel`
   - `com.rtls.kmp.*` → `com.rtls.location.*` for `AndroidLocationProvider`, `AndroidNetworkMonitor`
   - `com.rtls.kmp.*` → `com.rtls.client.*` for `RTLSClient`, `RTLSClientFactory`

4. **Replace factory calls** — migrate from `RTLSKmp.createLocationSyncClient(…)` to the Builder pattern:

   ```kotlin
   // Before
   val client = RTLSKmp.createLocationSyncClient(context, baseUrl, userId, deviceId, token, scope)
   val flow = RTLSKmp.createLocationFlow(context, userId, deviceId)

   // After
   val client = RTLSClientFactory.Builder(context)
       .baseUrl(baseUrl).userId(userId).deviceId(deviceId).accessToken(token)
       .offlineSync().webSocket().location()
       .build()
   val flow = builder.buildLocationFlow()
   ```

5. **Verify** — the `RTLSClient` API (`startCollectingLocation`, `stopTracking`, `stats`, `flushNow`, `events`) is unchanged.

---

## Technology Stack

| Concern | Implementation |
|---------|----------------|
| **Build** | Gradle Kotlin DSL, `kotlin("multiplatform")`, `androidTarget()`, Kotlin 1.9.x |
| **Serialization** | `kotlinx.serialization` (JSON) for API request/response payloads |
| **Concurrency** | Kotlin Coroutines, `Flow`, `SharedFlow`, `Mutex` (non-blocking `tryLock` for flush serialization) |
| **Persistence** | Raw Android SQLite — `INSERT OR REPLACE` for idempotent writes, `sent_at IS NULL` index scan for pending fetch |
| **Network (HTTP)** | OkHttp 4.x, `POST /v1/locations/batch`, Bearer token auth |
| **Network (WebSocket)** | OkHttp WebSocket, auto-reconnect with exponential backoff |
| **Network (monitor)** | `ConnectivityManager.registerDefaultNetworkCallback` → `callbackFlow` for reactive online/offline transitions |
| **Location** | `FusedLocationProviderClient` (Play Services, API >= 29) with `LocationManager` fallback (API <= 28), `callbackFlow` emission |

---

## License

See repository [LICENSE](../LICENSE).
