# rtls_flutter — Modular Flutter Location Sync SDK

The RTLS Flutter SDK has been restructured from a single monolithic plugin into **five independent packages** under [`packages/`](../packages/). Each package handles one concern, so you only pull in what you need — smaller dependency footprint, faster builds, and cleaner architecture.

> **Legacy note:** The original `rtls_flutter/` plugin still works and is maintained for backward compatibility, but new projects should adopt the modular packages. See [Migration Guide](#migration-guide) below.

---

## Package Overview

| Package | Type | Purpose | Depends on |
|---------|------|---------|------------|
| **rtls_core** | Pure Dart | Shared models: `RTLSLocationPoint`, `RTLSEvent` sealed hierarchy, `RTLSBatchingPolicy`, `RTLSTrackingPolicy` | — |
| **rtls_offline_sync** | Flutter plugin | Offline-first batch sync engine: configure, start, stop, insert, flushNow, pullNow, getStats. Bridges to native via Method/Event channels | rtls_core |
| **rtls_websocket** | Pure Dart | Real-time client over WebSocket: connect, disconnect, pushLocation, pushBatch, subscribe, unsubscribe. Auto-reconnect & ping. `RTLSWebSocketEvent` sealed hierarchy | rtls_core |
| **rtls_location** | Flutter plugin | Location tracking: configure, start, stop, `locations` stream. Bridges to native via Method/Event channels | rtls_core |
| **rtls_flutter_unified** | Dart | Orchestrator that combines all capabilities through optional dependency injection | rtls_core, rtls_offline_sync, rtls_websocket, rtls_location |

### Android Native Bridging

Each Flutter plugin delegates to its corresponding KMP module:

| Flutter plugin | KMP module |
|----------------|------------|
| rtls_offline_sync | `rtls-offline-sync` |
| rtls_location | `rtls-location` |

---

## Combination Matrix

Pick the packages that match your use case:

| Scenario | Packages needed |
|----------|-----------------|
| Offline batch sync only | `rtls_core` + `rtls_offline_sync` |
| Real-time WebSocket only | `rtls_core` + `rtls_websocket` |
| Background location tracking only | `rtls_core` + `rtls_location` |
| Location tracking + offline sync | `rtls_core` + `rtls_location` + `rtls_offline_sync` |
| Location tracking + real-time push | `rtls_core` + `rtls_location` + `rtls_websocket` |
| Full stack (all capabilities) | `rtls_core` + all four + `rtls_flutter_unified` |

---

## Quick Start

### Offline Sync Only

```dart
import 'package:rtls_offline_sync/rtls_offline_sync.dart';

final sync = RTLSOfflineSync();
await sync.configure(baseUrl: '...', userId: '...', deviceId: '...');
await sync.start();
await sync.insert([point1, point2]);
```

### WebSocket Only

```dart
import 'package:rtls_websocket/rtls_websocket.dart';

final ws = RTLSRealTimeClient(config: RTLSWebSocketConfig(baseUrl: '...'));
await ws.connect();
ws.pushLocation(point);
ws.subscribe('other-user');
ws.incomingLocations.listen((p) => print(p));
```

### Full Combo (Unified Client)

```dart
import 'package:rtls_flutter_unified/rtls_flutter_unified.dart';

final client = RTLSUnifiedClient(
  offlineSync: RTLSOfflineSync(),
  webSocket: RTLSRealTimeClient(config: wsConfig),
  locationTracker: RTLSLocationTracker(),
);
await client.configure(...);
await client.start();
```

The `RTLSUnifiedClient` accepts each capability as an optional parameter — pass only what you need and the orchestrator adapts accordingly.

---

## Migration Guide

Migrating from the legacy `rtls_flutter` monolithic plugin to the new modular packages:

### 1. Update dependencies

**Before (monolithic):**

```yaml
dependencies:
  rtls_flutter:
    path: ../rtls_flutter
```

**After (modular — pick what you need):**

```yaml
dependencies:
  rtls_core:
    path: ../packages/rtls_core
  rtls_offline_sync:
    path: ../packages/rtls_offline_sync
  rtls_location:
    path: ../packages/rtls_location
  rtls_websocket:
    path: ../packages/rtls_websocket
  rtls_flutter_unified:
    path: ../packages/rtls_flutter_unified
```

### 2. Replace imports

| Before | After |
|--------|-------|
| `import 'package:rtls_flutter/rtls_flutter.dart';` | `import 'package:rtls_offline_sync/rtls_offline_sync.dart';` |
| | `import 'package:rtls_websocket/rtls_websocket.dart';` |
| | `import 'package:rtls_location/rtls_location.dart';` |
| | `import 'package:rtls_flutter_unified/rtls_flutter_unified.dart';` |

### 3. Replace API calls

| Legacy API | New API |
|------------|---------|
| `RTLSync.configure(config)` | `RTLSOfflineSync().configure(...)` or `RTLSUnifiedClient(...).configure(...)` |
| `RTLSync.startTracking()` | `RTLSLocationTracker().start()` / `RTLSOfflineSync().start()` |
| `RTLSync.stopTracking()` | `RTLSLocationTracker().stop()` / `RTLSOfflineSync().stop()` |
| `RTLSync.flushNow()` | `RTLSOfflineSync().flushNow()` |
| `RTLSync.getStats()` | `RTLSOfflineSync().getStats()` |
| `RTLSync.events` (combined stream) | Individual streams per package, or `RTLSUnifiedClient` |

### 4. Android: update Gradle includes

Replace the single `:rtls_kmp` include with the specific KMP modules your chosen packages require (`rtls-offline-sync`, `rtls-location`).

---

## Legacy Plugin

The `rtls_flutter/` directory contains the original monolithic plugin. It is still functional but will not receive new features. All active development happens in the modular packages under `packages/`.

---

## License

See repository [LICENSE](../LICENSE).
