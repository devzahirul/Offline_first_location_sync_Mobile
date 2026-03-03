# Offline-First Real-Time Location Sync (iOS)

**A full-stack demo: iOS app, Swift packages, Node.js backend, and React dashboard** — built to show production-style offline-first design, background sync, and clean architecture.

---

## Why this project

Location tracking often fails in the real world: tunnels, weak signal, or battery-saving modes. This repo implements **offline-first** behavior: the app records location locally (SQLite), syncs when the network is available, and uses **background tasks** and lifecycle hooks to flush data without requiring the app to stay open. It’s the kind of system you’d want in fleet, delivery, or field-worker apps.

---

## Features

- **Offline-first** — Record to local SQLite; sync when online with configurable batching and retry
- **Background sync** — `BGProcessingTask` + app lifecycle hooks to upload pending points without keeping the app in foreground
- **Modular Swift** — Multi-target Swift Package (Core, Data, Sync, Platform, SyncKit) with testable core logic
- **Real-time dashboard** — React + TypeScript + Vite; Leaflet map; WebSocket stream of locations
- **REST + WebSocket API** — Node.js (Express, PostgreSQL, JWT, Zod); HTTP for uploads, WS for live subscription

---

## Tech stack

| Layer | Technologies |
|-------|--------------|
| **iOS** | Swift 5.9, SwiftPM, CoreLocation, BackgroundTasks, Combine |
| **Backend** | Node.js, Express, TypeScript, PostgreSQL, WebSocket (ws), JWT, Zod |
| **Dashboard** | React 19, TypeScript, Vite, Leaflet / react-leaflet |

---

## Architecture (high level)

```
[iOS App] → RTLSyncKit → RTLSSync (SyncEngine) → RTLSData (SQLite + HTTP/WS)
                ↑
         RTLSPlatformiOS (CoreLocation)
```

- **RTLSCore** — Types, policies (tracking, batching, retry, retention), store/API protocols  
- **RTLSData** — SQLite persistence, `URLSession` upload, WebSocket subscriber  
- **RTLSSync** — Sync engine, network monitoring  
- **RTLSyncKit** — Public API, `LocationSyncClient`, app lifecycle and background task scheduling  
- **RTLSPlatformiOS** — CoreLocation-backed location provider  

---

## Quick start

### Prerequisites

- **Xcode** (iOS 15+), **Node.js** 18+, **PostgreSQL** (for backend)

### 1. Backend

```bash
cd backend-nodejs
cp .env.example .env   # set DATABASE_URL, JWT_SECRET, etc.
npm install
npm run dev
```

### 2. Dashboard

```bash
cd rtls-dashboard
npm install
npm run dev
```

### 3. iOS app

1. Open `RealTimeLocationUpdateBackground/RealTimeLocationUpdateBackground.xcodeproj` in Xcode.
2. Set the app’s backend URL (e.g. in demo settings) to your backend (e.g. `http://localhost:3000` or your machine’s IP for a device).
3. Run on a device or simulator (device recommended for location).
4. Grant location permission and start tracking; watch the dashboard for live updates.

### 4. Run tests (Swift)

```bash
swift test
```

---

## Project structure

| Path | Description |
|------|-------------|
| `RealTimeLocationUpdateBackground/` | iOS app (SwiftUI, demo UI, map, settings) |
| `Sources/RTLSCore` | Core types, store/API protocols, policies |
| `Sources/RTLSData` | SQLite store, HTTP upload, WebSocket client |
| `Sources/RTLSSync` | Sync engine, network monitoring |
| `Sources/RTLSyncKit` | Public client API, lifecycle hooks, background sync |
| `Sources/RTLSPlatformiOS` | CoreLocation-based location provider |
| `Tests/RTLSCoreTests` | Unit tests for core logic |
| `backend-nodejs/` | Node.js API (REST + WebSocket, PostgreSQL) |
| `rtls-dashboard/` | React dashboard (Vite, TypeScript, Leaflet) |
| `rtls-react-native/` | React Native native module (iOS) wrapping RTLSyncKit |
| `rtls-mobile-example/` | Example React Native app using the module |
| `rtls-kmp/` | KMP shared module (Android-only): sync contract, SQLite, location, HTTP |
| `rtls-android-app/` | Native Android app using the KMP module |
| `rtls_flutter/` | Flutter plugin: Android uses KMP, iOS uses RTLSyncKit |

---

## Flutter, KMP, and Native Android

The repo includes a **KMP (Kotlin Multiplatform) shared module** (Android-only), a **Native Android app** that uses it, and a **Flutter plugin** that uses platform channels — on Android it calls into the KMP sync module; on iOS it calls into the Swift RTLSyncKit. All use the same backend (REST + WebSocket).

- **KMP module** (`rtls-kmp/`): Shared Kotlin implementing the same sync contract as RTLSyncKit (models, store, API client, sync engine). See [rtls-kmp/README.md](rtls-kmp/README.md) for build and usage.
- **Native Android app** (`rtls-android-app/`): Kotlin app with config screen (base URL, userId, deviceId, token), Start/Stop tracking, Flush, and pending-count display. See [rtls-android-app/README.md](rtls-android-app/README.md) for how to build and run.
- **Flutter plugin** (`rtls_flutter/`): Dart API (configure, startTracking, stopTracking, getStats, flushNow, event stream). On Android the plugin depends on the KMP module; on iOS it uses RTLSyncKit. See [rtls_flutter/README.md](rtls_flutter/README.md) for integration. The example app is at `rtls_flutter/example/`: run `flutter run` from the example directory. **Android:** The example’s `android/settings.gradle.kts` includes the KMP project so the plugin can resolve it. **iOS:** Add the RTLSyncKit Swift package in Xcode (File → Add Package Dependencies → path to this repo root) and add the **RTLSyncKit** library to the Runner target, same as for rtls-mobile-example.

---

## React Native (iOS)

React Native apps can use the same offline-first sync engine on iOS via the **rtls-react-native** native module, which wraps RTLSyncKit.

- **Add the package:** `npm install file:../rtls-react-native` (or from this repo root).
- **iOS:** Run `pod install` in your app's `ios/` folder. Then add the **RTLSyncKit** Swift package in Xcode (File → Add Package Dependencies → path to this repo root) and add the **RTLSyncKit** library to your app target. See `rtls-react-native/README.md` for the full API (configure, startTracking, stopTracking, getStats, events).
- **Example app:** `rtls-mobile-example/` is a minimal RN app that uses the module. After `cd rtls-mobile-example && npm install && cd ios && pod install`, run `ruby scripts/add_rtls_swift_package.rb` so the Pods project links RTLSyncKit, then build from Xcode or `npx react-native run-ios`.
- **Android:** Not implemented yet (planned: Kotlin or JS implementation using the same backend API).

---

## What I’d highlight in an interview

- **Offline-first**: Local-first storage, sync when online, and clear handling of pending/failed uploads.
- **Swift packaging**: Separated core, data, sync, and platform layers for testability and reuse.
- **Background behavior**: Use of `BGProcessingTask` and app lifecycle to sync without foreground usage.
- **Full stack**: One repo with iOS (Swift), backend (Node/TS), and dashboard (React) wired end-to-end.

---

## License

See [LICENSE](LICENSE) in this repository.
