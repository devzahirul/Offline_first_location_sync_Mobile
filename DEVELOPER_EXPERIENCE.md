# Developer Experience — Audit & Improvement Roadmap

L9-style audit of the RTLS offline-first sync stack (backend, iOS, Android/KMP, Flutter, React Native) with concrete improvements to make the library **easier for other developers to adopt**.

---

## Executive Summary

| Area | Current state | Target |
|------|----------------|--------|
| **API surface** | Consistent across Flutter / RN / native; config is verbose | Typed events (Flutter ✅); config factories; single “quick start” snippet |
| **Errors** | Backend 400 returned raw Zod issues; client saw "expected number, received undefined" | Human-readable one-liner + optional `details[]` (✅ done) |
| **Setup friction** | Flutter/RN require manual Gradle path + Swift package link | Document one-time steps; add script or template where possible |
| **Documentation** | READMEs are thorough but scattered | One “Quick start (all platforms)” in root README; this DX doc for depth |
| **Discoverability** | No pub.dev / npm “quick add” for monorepo | Document path/ Git dependency; optional: publish packages |

---

## 1. Backend — Sync Contract & Errors

### What’s good

- Single contract: `POST /v1/locations/batch`, `GET /v1/locations/latest`, `WS /v1/ws`.
- Zod validation; CORS; optional JWT; optional PostgreSQL.
- Health and discovery endpoints.

### Improvements (done / recommended)

| # | Improvement | Status |
|---|-------------|--------|
| 1 | **Human-readable 400 for batch** — First Zod issue as one sentence, e.g. `Validation failed: schemaVersion — expected number (missing)`. Optional `details[]` for tooling. | ✅ Done |
| 2 | **Gzip request body** — Already supported; ensure all clients send `Content-Encoding: gzip` and backend decompresses (✅). Document in API spec. | ✅ Done |
| 3 | **Structured error code** — Add `code: "VALIDATION_ERROR"` (or `AUTH_REQUIRED`, `SERVER_ERROR`) so clients can switch on code instead of parsing message. | Recommended |
| 4 | **OpenAPI / Postman** — Export `openapi.yaml` or a Postman collection for `POST /v1/locations/batch` (body schema, 400/401 examples). | Recommended |

---

## 2. Flutter — Plugin API & Events

### What’s good

- Single Dart API: `RTLSync.configure`, `startTracking`, `stopTracking`, `getStats`, `flushNow`, `requestAlwaysAuthorization`, `RTLSync.events`.
- README documents all config keys and event types.
- Example app is feature-complete.

### Improvements (done / recommended)

| # | Improvement | Status |
|---|-------------|--------|
| 1 | **Typed events** — Parse raw `Map` once into sealed event types (`RTLSRecordedEvent`, `RTLSyncEventPayloadEvent`, `RTLSyncErrorEvent`, etc.) so devs use `switch (event)` and get autocomplete. | ✅ Done |
| 2 | **Config factory** — `RTLSyncConfig.withDefaults(baseUrl, userId, deviceId: optional, accessToken: optional)` so minimal code is `configure(withDefaults(...))`. | ✅ Done |
| 3 | **Doc comments** — Add `///` on `RTLSyncConfig`, `RTLSync`, `RTLSyncEvent`, and key methods so IDE shows one-line help. | Recommended |
| 4 | **Example snippet in README** — Copy-paste “minimal app” (configure → request permission → start → listen events) in 15 lines. | Recommended |

---

## 3. React Native — Module API & Setup

### What’s good

- Same mental model as Flutter: `configure`, `startTracking`, `stopTracking`, `getStats`, `flushNow`, `requestAlwaysAuthorization`, `addEventListener`.
- TypeScript types exported; event names as `RTLSyncEvents` const.
- README explains Gradle include and Swift package link.

### Improvements (recommended)

| # | Improvement | Status |
|---|-------------|--------|
| 1 | **Typed event payloads** — `addEventListener` already uses generics; document the exact payload shapes for `rtls_recorded` and `rtls_syncEvent` in the type (e.g. `RTLSRecordedPoint`) so TS enforces. | Recommended |
| 2 | **Config factory** — `createRTLSConfig({ baseURL, userId, deviceId, accessToken?, ... })` with defaults for batch params. | Recommended |
| 3 | **Single “Install” section** — One page: 1) npm install (or path), 2) Android `settings.gradle` + permissions, 3) iOS pod + Swift package link. Numbered steps, no cross-linking. | Recommended |
| 4 | **RTLS_LITE** — Document the optional build flag for apps that never use location (no RTLSyncKit link); keep as optional. | Already in README |

---

## 4. KMP (Android) — Native & Consumer Setup

### What’s good

- Clear split: `commonMain` (engine, policies) vs `androidMain` (SQLite, OkHttp, FusedLocation, ConnectivityManager).
- `RTLSKmp.createLocationSyncClient` and `createLocationFlow` are the only entry points.
- README has flush algorithm, backoff, retention, and integration snippet.

### Improvements (recommended)

| # | Improvement | Status |
|---|-------------|--------|
| 1 | **Default `LocationRequestParams`** — Document recommended values for “battery” vs “high frequency” (e.g. `maxUpdateDelayMillis`, `useBalancedPowerAccuracy`) in one table. | Recommended |
| 2 | **Foreground service note** — README already says “host must start foreground service”; add one Kotlin snippet showing `startForegroundService(Intent(..., LocationService::class.java))` before `startCollectingLocation`. | Recommended |
| 3 | **Publish to Maven** — For consumers outside the monorepo, publish `rtls-kmp` to Maven Central or a private repo so they can `implementation("com.rtls:rtls-kmp:1.0.0")` instead of `project(":rtls-kmp")`. | Optional |

### Android: background vs terminated

- **Backgrounded:** App still in memory; foreground service keeps location and sync running. In-process flow + sync engine work as normal.
- **Process killed:** User swiped app away or system reclaimed memory. In-process callbacks stop. The Flutter plugin registers **PendingIntent** with `FusedLocationProviderClient`; the system can restart the process and deliver location to `RtlsLocationBroadcastReceiver`, which inserts into the same SQLite store. So **location continues to be stored** after “close”; **upload** runs on next app open (lifecycle flush) or when the app is in foreground.
- **Force‑stop:** User disabled the app in Settings → Force stop. No updates until the app is launched again.

See **rtls_flutter README § 4. Location when app is “closed”** for the table and upload behavior.

---

## 5. iOS (RTLSyncKit) — Native Consumer

### What’s good

- SwiftPM; actor-based SyncEngine; BGProcessingTask; NWPathMonitor.
- Configuration is one struct; README in repo root covers design.

### Improvements (recommended)

| # | Improvement | Status |
|---|-------------|--------|
| 1 | **Standalone “Integration” doc** — One page: add package, Info.plist keys, `LocationSyncClient(configuration:)`, start/stop, event stream. Copy-paste snippets. | Recommended |
| 2 | **Background Modes** — Explicit “Add capability: Background Modes → Location updates” with screenshot or Xcode step list. | Recommended |

---

## 6. Cross-Cutting — Quick Start & Consistency

### One “Quick start” for all platforms

Suggested addition to **root README**: a single section that links to the minimal path for each surface, with one snippet each.

```markdown
## Quick start by platform

| Platform | Steps | Minimal code |
|----------|--------|--------------|
| Flutter  | [Link to Flutter README § Quick start] | configure(withDefaults(...)); requestAlwaysAuthorization(); startTracking(); |
| React Native | [Link to RN README § Install] | configure({ baseURL, userId, deviceId, accessToken }); ... |
| Android (KMP) | [Link to KMP README § Integration] | RTLSKmp.createLocationSyncClient(...); createLocationFlow(...); startCollectingLocation(flow); |
| iOS (Swift) | [Link to root README or iOS doc] | LocationSyncClient(configuration: ...); startTracking(); |
```

### Naming consistency

- **Flutter:** `baseUrl`, `userId`, `deviceId`, `accessToken` (camelCase).
- **React Native:** `baseURL` (capital URL), same otherwise.
- **Backend:** `userId`, `deviceId`, `recordedAt` (camelCase in JSON).

Recommendation: keep as-is but document the single contract (e.g. “Backend expects camelCase; clients use baseUrl/baseURL per language convention”).

---

## 7. Implemented Changes (Summary)

- **Backend** — `POST /v1/locations/batch` 400 response now includes a top-level `error` string (e.g. `Validation failed: schemaVersion — expected number (missing)`) plus optional `details[]` for each Zod issue.
- **Flutter** — Typed event models: `RTLSyncEvent`, `RTLSRecordedPoint`, `RTLSyncEventPayload`, and `RTLSyncEvent.fromMap(raw)` for type-safe `switch (event)`. Added `RTLSyncConfig.withDefaults(...)` for quick config with sensible defaults.
- **Flutter (Android) — Location when app is closed** — Plugin now registers location updates via **PendingIntent** in addition to the in-process flow. When the app process is killed, the system can restart it to deliver location to `RtlsLocationBroadcastReceiver`, which writes into the same SQLite store. Points are uploaded on next app launch or when the app is in foreground. Documented in rtls_flutter README and § 4 above.

---

## 8. How to Use the New Flutter API

```dart
import 'package:rtls_flutter/rtls_flutter.dart';

// Quick config (e.g. local backend)
await RTLSync.configure(RTLSyncConfig.withDefaults(
  baseUrl: 'http://192.168.1.100:3000',
  userId: 'my-user',
  // deviceId and accessToken optional; defaults provided
));

// Type-safe event handling
RTLSync.events.listen((raw) {
  final event = RTLSyncEvent.fromMap(raw);
  if (event == null) return;
  switch (event) {
    case RTLSRecordedEvent(:final point):
      print('Recorded: ${point.lat}, ${point.lng}');
    case RTLSyncEventPayloadEvent(:final payload):
      if (payload.kind == 'uploadFailed') print('Upload failed: ${payload.message}');
    case RTLSyncErrorEvent(:final message):
      print('Error: $message');
    case RTLSyncTrackingStartedEvent():
      print('Tracking started');
    case RTLSyncTrackingStoppedEvent():
      print('Tracking stopped');
    case RTLSyncAuthorizationChangedEvent(:final authorization):
      print('Auth: $authorization');
  }
});
```

---

## 9. Next Steps (Priority Order)

1. **Root README** — Add “Quick start by platform” table (links + one snippet per row).
2. **Flutter README** — Add “Minimal app” 15-line snippet and document `RTLSyncConfig.withDefaults` and `RTLSyncEvent.fromMap`.
3. **Backend** — Add `code` to error responses; optional OpenAPI snippet.
4. **React Native** — Add config factory and single “Install” section.
5. **KMP README** — One table for “battery” vs “high frequency” params; one foreground service snippet.
6. **iOS** — Standalone integration page with copy-paste steps and Background Modes.

This document is the single place for “how we make RTLS easier for other developers”; implement items in the order above for maximum impact with minimal churn.
