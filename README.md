# RTLS -- Real-Time Location Sync

Modular, offline-first location telemetry SDK. Pick the capabilities you need -- GPS collection, offline sync, real-time WebSocket -- and compose them independently across iOS, Android, Flutter, and React Native. Zero data loss on network failure.

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

## Combination Matrix

Pick only the packages you need. Every package depends only on `core`.

| Use case | Packages needed |
|----------|----------------|
| Offline-first sync only (no GPS) | `core` + `offline-sync` |
| Background GPS + batch upload | `core` + `location` + `offline-sync` |
| Real-time WebSocket tracking | `core` + `location` + `websocket` |
| Offline-first + WebSocket (hybrid) | `core` + `location` + `offline-sync` + `websocket` |
| GPS collection only (no server) | `core` + `location` |
| Subscribe to another user's location | `core` + `websocket` |
| Full SDK (everything) | `core` + `location` + `offline-sync` + `websocket` + `client` |

---

## Platform Packages

### iOS (SwiftPM)

Five targets in `Package.swift`:

| Target | Path | Description |
|--------|------|-------------|
| `RTLSCore` | `Sources/RTLSCore/` | Models, interfaces, policies (`BatchingPolicy`, `SyncRetryPolicy`, `RetentionPolicy`) |
| `RTLSLocation` | `Sources/RTLSLocation/` | `CLLocationManager` provider, significant/continuous modes, `LocationRecordingDecider` |
| `RTLSOfflineSync` | `Sources/RTLSOfflineSync/` | `SyncEngine` actor, `SQLiteLocationStore` (WAL), `URLSessionLocationSyncAPI` (gzip), bidirectional pull/merge |
| `RTLSWebSocket` | `Sources/RTLSWebSocket/` | `RealTimeLocationClient`, `URLSessionRealTimeChannel`, auto-reconnect |
| `RTLSyncKit` | `Sources/RTLSyncKit/` | Optional orchestrator facade wiring all modules + `BGProcessingTask` |

### Android / KMP (Kotlin Multiplatform)

Five Gradle submodules under `rtls-kmp/`:

| Module | Path | Description |
|--------|------|-------------|
| `rtls-core` | `rtls-kmp/rtls-core/` | Models, interfaces, policies (commonMain) |
| `rtls-location` | `rtls-kmp/rtls-location/` | `FusedLocationProviderClient` + HW batching, `LocationRecordingDecider` |
| `rtls-offline-sync` | `rtls-kmp/rtls-offline-sync/` | `SyncEngine`, `SqliteLocationStore`, `OkHttpLocationSyncAPI` (gzip), bidirectional pull/merge |
| `rtls-websocket` | `rtls-kmp/rtls-websocket/` | `RealTimeLocationClient`, `OkHttpRealTimeChannel`, auto-reconnect |
| `rtls-client` | `rtls-kmp/rtls-client/` | Optional orchestrator (Builder pattern) |

### Flutter

Five packages under `packages/`:

| Package | Path | Description |
|---------|------|-------------|
| `rtls_core` | `packages/rtls_core/` | Dart types, interfaces, events |
| `rtls_location` | `packages/rtls_location/` | Background location (Dart API + native bridge) |
| `rtls_offline_sync` | `packages/rtls_offline_sync/` | Offline sync (Dart API + native bridge) |
| `rtls_websocket` | `packages/rtls_websocket/` | Pure Dart WebSocket client |
| `rtls_flutter_unified` | `packages/rtls_flutter_unified/` | Orchestrator (depends on all above) |

### React Native

| Path | Description |
|------|-------------|
| `rtls-react-native/` | Native module. iOS uses `RTLSyncKit`; Android uses `rtls-kmp`. Unified JS API. |

### Backend

| Path | Description |
|------|-------------|
| `backend-nodejs/` | Node.js + Express + PostgreSQL. REST batch upload + pull endpoint, JWT auth, WebSocket v2 protocol |

### Dashboard

| Path | Description |
|------|-------------|
| `rtls-dashboard/` | React 19 + Vite + Leaflet. WebSocket subscriber for live map |

---

## Quick Start

### Offline-First Sync Only

No GPS, no WebSocket -- just batch-upload data from any source with offline resilience.

**Android/KMP:**

```kotlin
val store = SqliteLocationStore(context)
val api = OkHttpLocationSyncAPI(baseUrl, tokenProvider)
val sync = OfflineSyncClient(store, api, batchingPolicy)
sync.start()

sync.insert(listOf(point1, point2))
// Data flows: SQLite → SyncEngine → HTTP POST → Server
// Server → HTTP GET → SyncEngine → SQLite (bidirectional pull)
```

**iOS:**

```swift
let store = try await SQLiteLocationStore(databaseURL: dbURL)
let api = URLSessionLocationSyncAPI(baseURL: url, tokenProvider: token)
let sync = OfflineSyncClient(store: store, api: api, batchingPolicy: policy)
await sync.start()
await sync.insert(points: [point1, point2])
```

### WebSocket Real-Time Only

Fire-and-forget push, no local storage.

**Android/KMP:**

```kotlin
val ws = RealTimeLocationClient(
    config = WebSocketConfig(baseUrl = "ws://server/v1/ws", token = "jwt"),
    channel = OkHttpRealTimeChannel()
)
ws.connect()
ws.pushLocation(point)

ws.subscribe("other-user-id")
ws.incomingLocations.collect { point -> updateMap(point) }
```

**iOS:**

```swift
let ws = RealTimeLocationClient(
    config: WebSocketConfig(baseURL: url, tokenProvider: token)
)
await ws.connect()
await ws.pushLocation(point)

for await point in ws.subscribe(userId: "other-user") {
    updateMap(point)
}
```

### Full: GPS + Offline Sync + WebSocket

The orchestrator wires everything together.

**Android/KMP:**

```kotlin
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

**iOS:**

```swift
let client = try await RTLSClient(
    configuration: .init(
        baseURL: url,
        authTokenProvider: token,
        userId: "user123",
        deviceId: "device456"
    ),
    offlineSync: .enabled(batchingPolicy: BatchingPolicy()),
    webSocket: .enabled(autoReconnect: true),
    location: .enabled(distanceFilter: 25)
)
await client.start()
```

---

## API Endpoints

All clients share the same backend contract.

### REST

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check |
| `POST` | `/v1/locations/batch` | Upload a batch of location points (gzip supported) |
| `GET` | `/v1/locations/latest?userId=` | Most recent point for a user |
| `GET` | `/v1/locations/pull?userId=&cursor=&limit=` | Cursor-based pagination for bidirectional sync |

**`POST /v1/locations/batch`** -- request:

```json
{
  "schemaVersion": 1,
  "points": [
    {
      "id": "uuid",
      "userId": "user-1",
      "deviceId": "device-1",
      "recordedAt": 1709500000000,
      "lat": 37.7749,
      "lng": -122.4194,
      "horizontalAccuracy": 5.0
    }
  ]
}
```

Response: `{ "acceptedIds": [...], "rejected": [], "serverTime": 1709500001000 }`

**`GET /v1/locations/pull`** -- cursor-based pagination for bidirectional sync:

| Parameter | Required | Description |
|-----------|----------|-------------|
| `userId` | Yes | User identifier |
| `cursor` | No | ISO 8601 timestamp; returns points after this time |
| `limit` | No | Max points per page (1-500, default 100) |

Response: `{ "points": [...], "nextCursor": "2024-01-01T00:00:00.000Z", "serverTime": 1709500000000 }`

When `nextCursor` is present, more pages are available. When absent, the client is fully caught up.

### WebSocket v2 Protocol (`/v1/ws`)

Bidirectional JSON messages over raw WebSocket. Supports authentication, location push, subscriptions, sync pull, and heartbeat.

**Client -> Server:**

| Type | Fields | Description |
|------|--------|-------------|
| `auth` | `token` | Authenticate with JWT |
| `location.push` | `reqId`, `point` | Push a single location point |
| `location.batch` | `reqId`, `points[]` | Push multiple points |
| `subscribe` | `userId` | Subscribe to live updates for a user |
| `unsubscribe` | `userId` | Unsubscribe from a user |
| `sync.pull` | `reqId`, `cursor?`, `limit?` | Request missing data (cursor-based) |
| `ping` | -- | Heartbeat |

**Server -> Client:**

| Type | Fields | Description |
|------|--------|-------------|
| `auth.ok` | -- | Authentication succeeded |
| `location.ack` | `reqId`, `pointId`, `status` | Single-point push acknowledgment |
| `location.batch_ack` | `reqId`, `acceptedIds[]`, `rejected[]` | Batch push acknowledgment |
| `location.update` | `point` | Live location update (from subscription) |
| `sync.result` | `reqId`, `points[]`, `cursor?`, `serverTime` | Pull response |
| `subscribed` | `userId` | Subscription confirmed |
| `pong` | -- | Heartbeat response |
| `error` | `message` | Error |

---

## Directory Structure

```
realTimeLocationSync/
├── Package.swift                        # iOS SwiftPM manifest (5 targets)
├── Sources/
│   ├── RTLSCore/                        # Models, interfaces, policies
│   ├── RTLSLocation/                    # CoreLocation provider
│   ├── RTLSOfflineSync/                 # SyncEngine + SQLite + HTTP API
│   ├── RTLSWebSocket/                   # Real-time bidirectional WebSocket
│   └── RTLSyncKit/                      # Optional orchestrator facade
├── rtls-kmp/                            # Android / Kotlin Multiplatform
│   ├── settings.gradle.kts              # includes 5 subprojects
│   ├── rtls-core/
│   ├── rtls-offline-sync/
│   ├── rtls-websocket/
│   ├── rtls-location/
│   └── rtls-client/
├── packages/                            # Flutter packages
│   ├── rtls_core/
│   ├── rtls_offline_sync/
│   ├── rtls_websocket/
│   ├── rtls_location/
│   └── rtls_flutter_unified/
├── rtls_flutter/                        # Legacy Flutter plugin
├── rtls-react-native/                   # React Native native module
├── backend-nodejs/                      # Node.js + Express + PostgreSQL
├── rtls-dashboard/                      # React + Vite + Leaflet
├── RealTimeLocationUpdateBackground/    # Native iOS example app
├── rtls-android-app/                    # Native Android example app
└── rtls-mobile-example/                 # React Native example app
```

---

## Getting Started

### Prerequisites

- **Backend:** Node.js 18+, PostgreSQL (optional -- in-memory fallback available)
- **iOS:** Xcode 15+, iOS 15+ target
- **Android:** Android Studio, SDK 21+, Gradle 8+
- **Flutter:** Flutter SDK stable channel
- **React Native:** Node.js, Xcode + CocoaPods (iOS), Android SDK (Android)

### 1. Start the backend

```bash
cd backend-nodejs
cp .env.example .env   # set DATABASE_URL, JWT_SECRET, HOST, PORT
npm install && npm run dev
```

### 2. Start the dashboard (optional)

```bash
cd rtls-dashboard
npm install && npm run dev
```

### 3. Run a client

**iOS (native):** Open `RealTimeLocationUpdateBackground.xcodeproj`, set base URL, run on device.

**Android (native):** `cd rtls-android-app && ./gradlew installDebug`

**Flutter:** `cd rtls_flutter/example && flutter run`

**React Native:** See [rtls-mobile-example/README.md](rtls-mobile-example/README.md)

### 4. Run tests

```bash
swift test                                    # iOS unit tests
cd rtls-kmp && ./gradlew assembleDebug        # Android library build
```

---

## Design Principles

**Offline-first, not offline-tolerant.** The local store is the system of record on the client. Upload is a background reconciliation process. If the device never comes online, every point is preserved locally with full fidelity.

**Modular by default.** Each capability (GPS, offline sync, WebSocket) is an independent package depending only on `core`. Users import exactly what they need. The orchestrator is optional.

**Shared sync semantics.** Both engines implement identical policies: `BatchingPolicy`, `SyncRetryPolicy`, `RetentionPolicy`. Same flush triggers, same backoff curve, same network gate.

**Idempotent writes.** `INSERT OR REPLACE` (Android) and `INSERT OR IGNORE` (iOS) ensure re-inserting a point with the same UUID is safe. The server deduplicates on `id`, making the write pipeline idempotent end-to-end.

**Failure model: leave pending, never corrupt.** Transport errors leave points in `pending` state for retry. Only explicit server rejections mark points as failed. A flaky connection never causes data loss.

**Serialized flush.** iOS uses Swift Actor isolation; Android uses a Kotlin `Mutex` with `tryLock`. Concurrent flush attempts are dropped, not queued.

---

## License

See [LICENSE](LICENSE).
