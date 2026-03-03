# Real-Time Location Sync (RTLS)

**Production-grade offline-first location tracking** — multi-platform clients, shared sync contract, and a single backend. Demonstrates scalable architecture, background sync, and clean separation of concerns across **iOS (Swift)**, **Android (Kotlin Multiplatform)**, **Flutter**, and **React Native**.

---

## Executive summary

This repository implements an **offline-first** location sync system: clients record GPS points to local storage (SQLite), batch-upload when the network is available, and optionally receive real-time updates via WebSocket. The design addresses real-world constraints: intermittent connectivity, tunnels, battery-saving modes, and the need to sync without keeping the app in the foreground.

**Key differentiators:**

- **Single backend contract** — All clients (native iOS, native Android, Flutter, React Native) consume the same REST and WebSocket API; no client-specific endpoints.
- **Shared sync semantics** — Swift (RTLSyncKit) and Kotlin (rtls-kmp) implement the same logical contract: models, store interface, batch upload, retry, and event stream.
- **Layered architecture** — Core types and policies are decoupled from persistence and platform; sync engine is testable without device or network.
- **Cross-platform coverage** — Native iOS (SwiftPM), native Android (KMP), Flutter (Android + iOS), React Native (Android + iOS); backend and dashboard are framework-agnostic.

---

## System architecture

```
                                    ┌─────────────────────────────────────┐
                                    │           Backend (Node.js)          │
                                    │  POST /v1/locations/batch           │
                                    │  GET  /v1/locations/latest           │
                                    │  WS   /v1/ws (live stream)           │
                                    └─────────────────┬───────────────────┘
                                                      │
         ┌────────────────────────────────────────────┼────────────────────────────────────────────┐
         │                                            │                                            │
         ▼                                            ▼                                            ▼
┌─────────────────┐                        ┌─────────────────┐                        ┌─────────────────┐
│   iOS (Swift)   │                        │ Android (KMP)    │                        │  Web dashboard   │
│ RTLSyncKit      │                        │ rtls-kmp         │                        │  React + Vite    │
│ CoreLocation    │                        │ FusedLocation    │                        │  WebSocket sub   │
│ BGProcessingTask│                        │ SQLite + OkHttp   │                        │  Leaflet map     │
└────────┬────────┘                        └────────┬────────┘                        └─────────────────┘
         │                                            │
         │  RTLSyncKit (SwiftPM)                       │  rtls-kmp (Gradle)
         │  RTLSCore → RTLSData → RTLSSync            │  commonMain → androidMain
         │                                            │
         ▼                                            ▼
┌─────────────────┐                        ┌─────────────────┐
│ Flutter (iOS)   │                        │ Flutter (Android)│
│ → RTLSyncKit    │                        │ → rtls-kmp      │
└────────┬────────┘                        └────────┬────────┘
         │                                            │
         └────────────────────┬───────────────────────┘
                               │
         ┌────────────────────┴─────────────────────┐
         ▼                                            ▼
┌─────────────────┐                        ┌─────────────────┐
│ React Native    │                        │ React Native    │
│ (iOS)           │                        │ (Android)       │
│ → RTLSyncKit    │                        │ → rtls-kmp      │
└─────────────────┘                        └─────────────────┘
```

- **Backend:** Stateless HTTP + stateful WebSocket; optional PostgreSQL for persistence; JWT for auth.
- **Clients:** Local SQLite (or equivalent), configurable batching/retry, event stream for UI (pending count, last sync, errors).
- **Dashboard:** Subscribes to WebSocket for live locations; no direct DB access.

---

## Technology stack

| Layer | Technologies | Notes |
|-------|--------------|--------|
| **iOS (native)** | Swift 5.9, SwiftPM, CoreLocation, BackgroundTasks, Combine | Multi-target package: Core, Data, Sync, Platform, SyncKit |
| **Android (native)** | Kotlin 1.9, KMP (android target), SQLite, OkHttp, FusedLocationProvider | commonMain + androidMain; consumed by native app, Flutter, and React Native on Android |
| **Flutter** | Dart 3, MethodChannel / EventChannel | Android → rtls-kmp; iOS → RTLSyncKit |
| **React Native** | JavaScript/TypeScript, native modules (Swift + Kotlin) | iOS → RTLSyncKit; Android → rtls-kmp; same JS API both platforms |
| **Backend** | Node.js, Express, TypeScript, Zod, ws, pg, jsonwebtoken | REST + WebSocket; optional PostgreSQL |
| **Dashboard** | React 19, TypeScript, Vite, Leaflet | WebSocket client; no server-side rendering |

---

## Repository structure

| Path | Description |
|------|-------------|
| `RealTimeLocationUpdateBackground/` | Native iOS app (SwiftUI); demo UI, map, settings |
| `Sources/RTLSCore` | Core types, store/API protocols, batching/retry policies |
| `Sources/RTLSData` | SQLite persistence, HTTP upload, WebSocket client |
| `Sources/RTLSSync` | Sync engine, network awareness |
| `Sources/RTLSyncKit` | Public API: `LocationSyncClient`, lifecycle, background scheduling |
| `Sources/RTLSPlatformiOS` | CoreLocation-based location provider |
| `Tests/RTLSCoreTests` | Unit tests for core logic |
| `backend-nodejs/` | Node.js API; see [backend-nodejs/README.md](backend-nodejs/README.md) |
| `rtls-dashboard/` | React dashboard; see [rtls-dashboard/README.md](rtls-dashboard/README.md) |
| `rtls-kmp/` | KMP shared module (Android); see [rtls-kmp/README.md](rtls-kmp/README.md) |
| `rtls-android-app/` | Native Android app; see [rtls-android-app/README.md](rtls-android-app/README.md) |
| `rtls_flutter/` | Flutter plugin (iOS + Android); see [rtls_flutter/README.md](rtls_flutter/README.md) |
| `rtls-react-native/` | React Native native module (iOS + Android); see [rtls-react-native/README.md](rtls-react-native/README.md) |
| `rtls-mobile-example/` | Example React Native app; see [rtls-mobile-example/README.md](rtls-mobile-example/README.md) |

---

## Quick start

### Prerequisites

- **Backend / Dashboard:** Node.js 18+, PostgreSQL (optional; in-memory fallback if not configured)
- **iOS:** Xcode (iOS 15+)
- **Android:** Android Studio or CLI; SDK 21+
- **Flutter:** Flutter SDK (stable)
- **React Native:** Node.js; Xcode + CocoaPods (iOS); Android SDK (Android)

### 1. Backend

```bash
cd backend-nodejs
cp .env.example .env   # configure DATABASE_URL, JWT_SECRET, HOST, PORT
npm install
npm run dev
```

See [backend-nodejs/README.md](backend-nodejs/README.md) for API specification and environment variables.

### 2. Dashboard (optional)

```bash
cd rtls-dashboard
npm install
npm run dev
```

Open the app and subscribe to the WebSocket to view live locations.

### 3. Run a client

- **iOS app:** Open `RealTimeLocationUpdateBackground/RealTimeLocationUpdateBackground.xcodeproj`, set base URL (e.g. `http://<your-ip>:3000`), run on device/simulator.
- **Android app:** `cd rtls-android-app && ./gradlew installDebug`; configure base URL, user/device/token, then Start tracking.
- **Flutter example:** `cd rtls_flutter/example && flutter run`; see [rtls_flutter/README.md](rtls_flutter/README.md) for host app integration (Android: include rtls-kmp; iOS: link RTLSyncKit in Xcode).
- **React Native example:** See [rtls-mobile-example/README.md](rtls-mobile-example/README.md) for install; iOS: link RTLSyncKit in Xcode; Android: include rtls-kmp in `settings.gradle`.

### 4. Run Swift tests

```bash
swift test
```

---

## Backend API contract (summary)

All mobile clients use the same contract:

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST` | `/v1/locations/batch` | Upload batch of location points (JSON; JWT in `Authorization`) |
| `GET` | `/v1/locations/latest?userId=` | Latest stored point for a user (JWT required) |
| WebSocket | `/v1/ws` | Subscribe; server broadcasts `{ type: "location", point }` on new data |

Batch payload: `{ schemaVersion, points: [ { id, userId, deviceId, recordedAt (ms), lat, lng, ... } ] }`. Response: `{ acceptedIds, rejected, serverTime }`. See [backend-nodejs/README.md](backend-nodejs/README.md) for schemas and validation.

---

## Flutter, KMP, and Native Android

- **rtls-kmp:** Kotlin Multiplatform module (Android target only). Implements the same logical sync contract as RTLSyncKit: models, `LocationStore`, `LocationSyncAPI`, sync engine, `LocationSyncClient`. Consumed by the native Android app, the Flutter plugin on Android, and the React Native module on Android. [rtls-kmp/README.md](rtls-kmp/README.md)
- **rtls-android-app:** Standalone Kotlin/Android app: config screen (base URL, userId, deviceId, token), Start/Stop, Flush, pending count and last event. [rtls-android-app/README.md](rtls-android-app/README.md)
- **rtls_flutter:** Flutter plugin; Dart API (configure, startTracking, stopTracking, getStats, flushNow, event stream). **Android** uses rtls-kmp; **iOS** uses RTLSyncKit. Host app must include rtls-kmp in Gradle (Android) and link RTLSyncKit in Xcode (iOS). [rtls_flutter/README.md](rtls_flutter/README.md)

---

## React Native (iOS and Android)

The **rtls-react-native** package exposes the same JavaScript API on both platforms: configure, start/stop tracking, getStats, flushNow, and event listeners (RECORDED, SYNC_EVENT, ERROR, etc.). **iOS:** native module wraps RTLSyncKit; app must link the RTLSyncKit Swift package in Xcode. **Android:** native module wraps rtls-kmp; app must include the rtls-kmp project in `settings.gradle` and declare location permissions. [rtls-react-native/README.md](rtls-react-native/README.md). Example: [rtls-mobile-example/README.md](rtls-mobile-example/README.md).

---

## Design highlights (for technical review)

- **Offline-first:** Write path is local (SQLite); read path can show pending count and last sync without network. Upload is best-effort with retry and backoff.
- **Layered Swift package:** RTLSCore (types, policies) has no platform dependency; RTLSData and RTLSSync depend on store/API abstractions; RTLSyncKit and RTLSPlatformiOS provide concrete implementations and lifecycle.
- **Background sync (iOS):** BGProcessingTask and app lifecycle hooks trigger flush without foreground execution; Android can use foreground service or WorkManager for analogous behavior.
- **Single source of truth:** Backend is the authority for persisted locations; clients are writers and optional readers (latest, WebSocket).
- **Security:** JWT in `Authorization` for REST and WebSocket; no auth bypass in production config. Token refresh is out of scope for v1.

---

## License

See [LICENSE](LICENSE) in this repository.
