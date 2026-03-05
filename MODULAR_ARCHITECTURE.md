# RTLS Modular Architecture

## Philosophy

Every capability is an **independent package** that depends only on `rtls-core`.
Users pick exactly what they need — no wasted code, no forced coupling.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        rtls-core                                    │
│  Models · Interfaces · Policies · AuthTokenProvider                 │
└──────────┬──────────────┬──────────────┬───────────────────────────┘
           │              │              │
     ┌─────▼─────┐  ┌────▼────┐  ┌──────▼──────┐
     │ rtls-      │  │ rtls-   │  │ rtls-       │
     │ offline-   │  │ web-    │  │ location    │
     │ sync       │  │ socket  │  │             │
     │            │  │         │  │ GPS collect │
     │ SQLite     │  │ Bidir   │  │ Recording   │
     │ SyncEngine │  │ push/sub│  │ decider     │
     │ HTTP batch │  │ auto-   │  │ Background  │
     │ Pull/merge │  │ reconnect  │ service     │
     └────────────┘  └─────────┘  └─────────────┘
           │              │              │
           └──────────────┼──────────────┘
                          │
                   ┌──────▼──────┐
                   │ rtls-client │   ← optional orchestrator
                   │ Wires any   │
                   │ combination │
                   └─────────────┘
```

---

## User Combination Matrix

| Use case | Packages needed |
|----------|----------------|
| Offline-first sync only (no GPS) | `core` + `offline-sync` |
| Background GPS + batch upload | `core` + `location` + `offline-sync` |
| Real-time WebSocket tracking | `core` + `location` + `websocket` |
| Offline-first + WebSocket (hybrid) | `core` + `location` + `offline-sync` + `websocket` |
| Just GPS collection (no server) | `core` + `location` |
| Subscribe to another user | `core` + `websocket` |
| Full SDK (everything) | `core` + `location` + `offline-sync` + `websocket` + `client` |

---

## Package Details

### 1. `rtls-core` — Shared contracts

Zero dependencies. Every other package depends only on this.

| Component | Purpose |
|-----------|---------|
| `LocationPoint` | Universal data model (id, userId, lat/lng, accuracy, etc.) |
| `GeoCoordinate` | Latitude/longitude pair with haversine distance |
| `LocationStore` | Persistence interface (insert, fetchPending, markSent, markFailed) |
| `LocationSyncAPI` | HTTP upload interface (`upload(batch) → result`) |
| `NetworkMonitor` | Online/offline detection interface |
| `AuthTokenProvider` | Bearer token provider |
| `BatchingPolicy` | When to flush (maxBatchSize, flushInterval, maxBatchAge) |
| `SyncRetryPolicy` | Exponential backoff (baseDelay, maxDelay, jitter) |
| `RetentionPolicy` | Local data pruning (sentPointsMaxAge) |
| `LocationUploadBatch/Result` | Upload request/response models |
| `SentPointsPrunableLocationStore` | Optional: prune old sent points |

### 2. `rtls-offline-sync` — Offline-first batch sync engine

Depends on: `rtls-core`

| Component | Purpose |
|-----------|---------|
| `SyncEngine` | Timer-driven batch upload with backoff, network gating, retention pruning |
| `SqliteLocationStore` | SQLite WAL-mode store implementing `LocationStore` + `BidirectionalLocationStore` |
| `OkHttpLocationSyncAPI` (Android) / `URLSessionLocationSyncAPI` (iOS) | Gzip-compressed HTTP upload |
| `BidirectionalLocationStore` | Pull-side: apply server changes with merge strategy |
| `LocationPullAPI` | Interface for fetching server changes (cursor-based pagination) |
| `LocationMergeStrategy` | Conflict resolution: keepLocal / keepServer / custom merge |
| `OfflineSyncClient` | Standalone facade — configure + start + stop + flushNow + pullNow |

**Standalone usage (no location, no WebSocket):**
```kotlin
// Android/KMP
val store = SqliteLocationStore(context)
val api = OkHttpLocationSyncAPI(baseUrl, tokenProvider)
val sync = OfflineSyncClient(store, api, batchingPolicy)
sync.start()

// Insert data from any source
sync.insert(listOf(point1, point2))

// Data flows: SQLite → SyncEngine → HTTP POST → Server
// Server → HTTP GET → SyncEngine → SQLite (bidirectional pull)
```

```swift
// iOS
let store = try await SQLiteLocationStore(databaseURL: dbURL)
let api = URLSessionLocationSyncAPI(baseURL: url, tokenProvider: token)
let sync = OfflineSyncClient(store: store, api: api, batchingPolicy: policy)
await sync.start()
await sync.insert(points: [point1, point2])
```

### 3. `rtls-websocket` — Real-time bidirectional WebSocket

Depends on: `rtls-core`

| Component | Purpose |
|-----------|---------|
| `RealTimeChannel` | Interface: connect, disconnect, send, receive |
| `OkHttpRealTimeChannel` (Android) / `URLSessionRealTimeChannel` (iOS) | Platform WebSocket impl |
| `WebSocketConfig` | URL, token, reconnect policy |
| `WebSocketMessages` | Protocol message types (auth, push, ack, subscribe, etc.) |
| `RealTimeLocationClient` | High-level API: pushLocation, subscribe, incoming stream |

**WebSocket Protocol v2 (bidirectional):**

```
Client → Server:
  { "type": "auth",           "token": "jwt" }
  { "type": "location.push",  "reqId": "uuid", "point": {...} }
  { "type": "location.batch", "reqId": "uuid", "points": [...] }
  { "type": "subscribe",      "userId": "user123" }
  { "type": "unsubscribe",    "userId": "user123" }
  { "type": "sync.pull",      "reqId": "uuid", "cursor": "..." }
  { "type": "ping" }

Server → Client:
  { "type": "auth.ok" }
  { "type": "location.ack",       "reqId": "uuid", "status": "accepted" }
  { "type": "location.batch_ack", "reqId": "uuid", "acceptedIds": [...] }
  { "type": "location.update",    "point": {...} }
  { "type": "sync.result",        "reqId": "uuid", "points": [...], "cursor": "..." }
  { "type": "subscribed",         "userId": "user123" }
  { "type": "pong" }
  { "type": "error",              "message": "..." }
```

**Standalone usage (fire-and-forget real-time, no local storage):**
```kotlin
// Android/KMP
val ws = RealTimeLocationClient(
    config = WebSocketConfig(baseUrl = "ws://server/v1/ws", token = "jwt"),
    channel = OkHttpRealTimeChannel()
)
ws.connect()

// Push locations in real-time
ws.pushLocation(point)

// Subscribe to another user
ws.subscribe("other-user-id")
ws.incomingLocations.collect { point -> updateMap(point) }
```

```swift
// iOS
let ws = RealTimeLocationClient(
    config: WebSocketConfig(baseURL: url, tokenProvider: token)
)
await ws.connect()
await ws.pushLocation(point)

for await point in ws.subscribe(userId: "other-user") {
    updateMap(point)
}
```

### 4. `rtls-location` — Background GPS collection

Depends on: `rtls-core`

| Component | Purpose |
|-----------|---------|
| `LocationSource` | Interface: `locationFlow() → Flow<LocationPoint>` |
| `LocationRecordingDecider` | Accuracy/time/distance gates to filter junk GPS |
| `AndroidLocationProvider` (Android) | FusedLocationProviderClient + LocationManager fallback |
| `LocationProvider` (iOS) | CLLocationManager with significant/continuous modes |
| `LocationRequestParams` / `LocationProvider.Configuration` | Hardware config |

**Standalone usage (just collect GPS, no sync):**
```kotlin
// Android/KMP
val provider = AndroidLocationProvider(context)
val decider = LocationRecordingDecider(minDistanceMeters = 25.0)

provider.locationFlow(userId, deviceId).collect { point ->
    if (decider.shouldRecord(point)) {
        decider.markRecorded(point)
        saveToMyOwnDatabase(point)
    }
}
```

```swift
// iOS
let provider = LocationProvider(configuration: .init(distanceFilter: 25))
for await event in provider.events {
    if case .didUpdate(let sample) = event {
        saveToMyOwnDatabase(sample)
    }
}
```

### 5. `rtls-client` — Optional orchestrator

Depends on: `rtls-core` + optionally any combination of the above

Provides `RTLSClient` — a convenience facade that wires selected packages together.
Users who want everything just use this. Users who want control use individual packages directly.

```kotlin
// Full combo: GPS + offline sync + real-time WebSocket
val client = RTLSClient.Builder(context)
    .baseUrl("https://api.example.com")
    .userId("user123")
    .deviceId("device456")
    .offlineSync(batchingPolicy = BatchingPolicy(maxBatchSize = 100))
    .webSocket(autoReconnect = true)
    .location(minDistance = 25.0)
    .build()

client.start()
client.events.collect { event -> handleEvent(event) }
```

```swift
// iOS: offline sync + WebSocket (no GPS — data inserted manually)
let client = try await RTLSClient(
    configuration: .init(
        baseURL: url,
        authTokenProvider: token,
        userId: "user123",
        deviceId: "device456"
    ),
    offlineSync: .enabled(batchingPolicy: BatchingPolicy()),
    webSocket: .enabled(autoReconnect: true),
    location: .disabled
)
await client.start()
```

---

## Backend Changes

### New: Pull Endpoint (for bidirectional sync)

```
GET /v1/locations/pull?userId=X&cursor=Y&limit=Z

Response:
{
  "points": [...],
  "nextCursor": "2024-01-01T00:00:00.000Z",
  "serverTime": 1709500000000
}
```

### Enhanced: WebSocket v2 Protocol

The WebSocket at `/v1/ws` now supports bidirectional communication:

1. **Authentication**: Client sends `{ type: "auth", token: "..." }`, server responds `{ type: "auth.ok" }`
2. **Push location**: Client sends point, server stores + broadcasts + acks
3. **Subscribe**: Client subscribes to a userId, receives live updates
4. **Sync pull over WS**: Client requests missing data, server streams it back
5. **Heartbeat**: ping/pong for connection health

---

## Directory Structure (All Platforms)

### KMP (Kotlin Multiplatform)
```
rtls-kmp/
├── settings.gradle.kts          # includes all 5 subprojects
├── build.gradle.kts             # root plugins
├── rtls-core/
│   ├── build.gradle.kts
│   └── src/commonMain/kotlin/com/rtls/core/
├── rtls-offline-sync/
│   ├── build.gradle.kts
│   └── src/{commonMain,androidMain}/kotlin/com/rtls/sync/
├── rtls-websocket/
│   ├── build.gradle.kts
│   └── src/{commonMain,androidMain}/kotlin/com/rtls/websocket/
├── rtls-location/
│   ├── build.gradle.kts
│   └── src/{commonMain,androidMain}/kotlin/com/rtls/location/
└── rtls-client/
    ├── build.gradle.kts
    └── src/{commonMain,androidMain}/kotlin/com/rtls/client/
```

### iOS (SwiftPM)
```
Sources/
├── RTLSCore/              # Models, interfaces, policies (unchanged)
├── RTLSLocation/          # CoreLocation provider (renamed from RTLSPlatformiOS)
├── RTLSOfflineSync/       # SyncEngine + SQLite + HTTP API
├── RTLSWebSocket/         # Real-time bidirectional WebSocket
└── RTLSyncKit/            # Optional orchestrator facade
```

### Flutter
```
packages/
├── rtls_core/             # Dart types, interfaces, events
├── rtls_offline_sync/     # Offline sync (Dart API + native bridge)
├── rtls_websocket/        # Pure Dart WebSocket client
├── rtls_location/         # Background location (Dart API + native bridge)
└── rtls_flutter/          # Orchestrator (depends on all above)
```

---

## Data Flow Diagrams

### Pattern A: Offline-First Only
```
[Any Data Source] → insert() → [SQLite Store]
                                     │
                              SyncEngine (timer/trigger)
                                     │
                              HTTP POST /v1/locations/batch
                                     │
                              HTTP GET /v1/locations/pull  (bidirectional)
                                     │
                              [SQLite Store] ← merge strategy
```

### Pattern B: WebSocket Real-Time Only
```
[GPS or Any Source] → pushLocation() → [WebSocket] → Server
                                              │
Server → [WebSocket] → incomingLocations → [Consumer]
```

### Pattern C: Hybrid (Offline + WebSocket)
```
[GPS] → insert() → [SQLite Store]  (always, for durability)
   │
   └──→ pushLocation() → [WebSocket] → Server  (when online, for speed)
                                │
SyncEngine → HTTP batch → Server  (background catch-up for offline gaps)
                                │
Server → [WebSocket] → merge → [SQLite Store]  (real-time pull)
```

### Pattern D: Location + WebSocket (No Storage)
```
[GPS] → filter(RecordingDecider) → pushLocation() → [WebSocket] → Server
                                                          │
Server → [WebSocket] → callback → [UI]
```

---

## Migration Guide (from monolithic SDK)

1. Replace `implementation(project(":rtls_kmp"))` with specific modules:
   - `implementation(project(":rtls-core"))`
   - `implementation(project(":rtls-offline-sync"))` (if using offline sync)
   - `implementation(project(":rtls-websocket"))` (if using WebSocket)
   - `implementation(project(":rtls-location"))` (if using GPS)
   - `implementation(project(":rtls-client"))` (if using the convenience facade)

2. Update imports from `com.rtls.kmp.*` to:
   - `com.rtls.core.*` for models and interfaces
   - `com.rtls.sync.*` for offline sync
   - `com.rtls.websocket.*` for WebSocket
   - `com.rtls.location.*` for GPS
   - `com.rtls.client.*` for the facade

3. For iOS, update `Package.swift` dependencies:
   - `RTLSCore` (always)
   - `RTLSOfflineSync` (if using offline sync)
   - `RTLSWebSocket` (if using WebSocket)
   - `RTLSLocation` (if using GPS)
   - `RTLSyncKit` (if using the full facade)
