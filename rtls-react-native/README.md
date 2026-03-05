# rtls-react-native

React Native native module providing **offline-first location sync** with a unified JavaScript API across **iOS and Android**. iOS delegates to the [RTLSyncKit](https://github.com/devzahirul/Offline_first_location_sync_iOS) Swift engine; Android wraps the shared [rtls-kmp](../rtls-kmp/README.md) Kotlin Multiplatform sync engine — the same core that powers the native Android app and the Flutter plugin's Android layer.

> **Modular architecture (v2):** Both native engines have been restructured into independent modules. The Android side now consumes individual KMP Gradle modules (`rtls-core`, `rtls-offline-sync`, `rtls-location`) instead of the monolithic `rtls-kmp` artifact. The iOS side can depend on individual SwiftPM targets (`RTLSOfflineSync`, `RTLSWebSocket`, `RTLSLocation`) or the umbrella `RTLSyncKit`. See [MODULAR_ARCHITECTURE.md](../MODULAR_ARCHITECTURE.md) for details.

---

## Architecture

```
┌──────────────────────────────────────────────┐
│              JS / TypeScript                  │
│  RTLSync.configure ─ startTracking ─ stop    │
│  getStats ─ flushNow ─ requestAlwaysAuth     │
│  NativeEventEmitter → event subscriptions    │
├──────────────┬───────────────────────────────┤
│  iOS (Swift) │        Android (Kotlin)       │
│  RTLSyncKit  │        rtls-core              │
│  (modular:   │        rtls-offline-sync      │
│  RTLSLocation│        rtls-location          │
│  RTLSOffline │        FusedLocation +        │
│  RTLSWebSock)│        ForegroundService      │
└──────────────┴───────────────────────────────┘
```

Both platforms converge on the same backend contract: `POST /v1/locations/batch`, `GET /v1/locations/latest`, `GET /v1/locations/pull`, WebSocket `/v1/ws` (v2 protocol with bidirectional push).

---

## TypeScript API

### Types

```ts
interface RTLSConfigureConfig {
  baseURL: string;
  userId: string;
  deviceId: string;
  accessToken: string;
  batchMaxSize?: number;
  flushIntervalSeconds?: number;
  maxBatchAgeSeconds?: number;
  locationIntervalSeconds?: number;
  locationDistanceMeters?: number;
  useSignificantLocationOnly?: boolean;
}

interface RTLSStats {
  pendingCount: number;
  oldestPendingRecordedAt: number | null;
}

interface RTLSRecordedPoint {
  id: string;
  userId: string;
  deviceId: string;
  recordedAt: number;
  lat: number;
  lng: number;
  horizontalAccuracy?: number;
  altitude?: number;
  speed?: number;
  course?: number;
}

interface RTLSyncEventPayload {
  type: 'uploadSucceeded' | 'uploadFailed';
  accepted?: number;
  rejected?: number;
  message?: string;
}

type RTLSAuthorizationStatus =
  | 'notDetermined'
  | 'restricted'
  | 'denied'
  | 'authorizedWhenInUse'
  | 'authorizedAlways';
```

### Core Methods

```ts
import RTLSync from 'rtls-react-native';

await RTLSync.configure({
  baseURL: 'https://api.example.com',
  userId: 'user-1',
  deviceId: 'device-1',
  accessToken: 'jwt-token',
  batchMaxSize: 50,
  flushIntervalSeconds: 30,
  maxBatchAgeSeconds: 120,
  locationIntervalSeconds: 360,
  locationDistanceMeters: 100,
  useSignificantLocationOnly: false,
});

await RTLSync.requestAlwaysAuthorization();
await RTLSync.startTracking();
await RTLSync.stopTracking();

const stats = await RTLSync.getStats();
await RTLSync.flushNow();
```

### Events via NativeEventEmitter

```ts
import RTLSync from 'rtls-react-native';

const sub = RTLSync.addEventListener('rtls_recorded', (point: RTLSRecordedPoint) => {
  // Full location point with accuracy, altitude, speed, course
});

const syncSub = RTLSync.addEventListener('rtls_syncEvent', (e: RTLSyncEventPayload) => {
  // uploadSucceeded → e.accepted, e.rejected
  // uploadFailed   → e.message
});

// Cleanup
sub.remove();
syncSub.remove();
```

**Event names:** `rtls_recorded`, `rtls_syncEvent`, `rtls_error`, `rtls_authorizationChanged`, `rtls_trackingStarted`, `rtls_trackingStopped`.

All events are emitted through React Native's `NativeEventEmitter`, ensuring thread-safe delivery on the JS thread regardless of which native thread originated the event.

---

## Android Integration

### 1. Include KMP modules

The module's Android layer depends on individual KMP Gradle modules rather than the monolithic `rtls-kmp`. The host app must include the required modules.

**android/settings.gradle.kts:**

```kotlin
include(":rtls-core")
project(":rtls-core").projectDir = file("../../rtls-kmp/rtls-core")

include(":rtls-offline-sync")
project(":rtls-offline-sync").projectDir = file("../../rtls-kmp/rtls-offline-sync")

include(":rtls-location")
project(":rtls-location").projectDir = file("../../rtls-kmp/rtls-location")
```

> The legacy single-include `include(":rtls_kmp")` still works but pulls in all modules. Prefer individual includes to keep the dependency footprint minimal.

### 2. Permissions

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

`requestAlwaysAuthorization()` triggers the actual Android runtime permission flow. `startTracking()` verifies permission state before activating the location provider. `LocationRequestParams` and `BatchingPolicy` are derived from the config passed at `configure()` time.

### 3. Build

```bash
npx react-native run-android
```

---

## iOS Integration

### 1. CocoaPods

```bash
cd ios && pod install
```

### 2. Link RTLSyncKit Swift package

1. Open `ios/YourApp.xcworkspace` in Xcode.
2. **File → Add Package Dependencies…** → add the repo root (or Git URL) containing `Package.swift`.
3. Link **RTLSyncKit** to the app target (General → Frameworks, Libraries, and Embedded Content).

Without this step the build fails with `Unable to find module 'RTLSyncKit'`.

> **Selective linking:** RTLSyncKit is now an umbrella that re-exports independent SwiftPM targets. If you only need a subset of functionality, you can link individual targets instead: `RTLSOfflineSync`, `RTLSWebSocket`, `RTLSLocation`, or `RTLSCore`.

**Runtime optimization:** RTLSyncKit is linked at launch but performs zero work (no SQLite, no CoreLocation, no networking) until `configure()` and `startTracking()` are called. The sync engine initializes lazily.

### Optional: RTLS_LITE build

For app variants that never use location sync, omit the Swift package and set the `RTLS_LITE` compilation condition:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |t|
    if t.name == 'rtls-react-native'
      t.build_configurations.each do |config|
        config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] ||= ['$(inherited)']
        config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] << 'RTLS_LITE'
      end
    end
  end
end
```

All methods reject with `"RTLSyncKit not linked"` — the module compiles and loads without the Swift dependency.

### 3. Build

```bash
npx react-native run-ios
```

---

## Platform Summary

| | iOS | Android |
|---|-----|---------|
| **Engine** | RTLSyncKit (Swift, modular targets) | rtls-kmp (modular Gradle modules) |
| **Background** | CLLocationManager always-authorization | Foreground service + FusedLocationProvider |
| **Host Setup** | Link RTLSyncKit (or individual targets); CocoaPods | Include `:rtls-core`, `:rtls-offline-sync`, `:rtls-location` in Gradle; manifest permissions |
| **Permission API** | Maps to CLLocationManager | Maps to ActivityCompat runtime permission |

---

## Example App

See [rtls-mobile-example/README.md](../rtls-mobile-example/README.md) — a cross-platform React Native demo covering install order, Swift package linking, Gradle subproject inclusion, and full API usage.

---

## Modular Architecture

The RTLS SDK has been restructured into independent packages across all platforms:

- **KMP (Android):** 5 Gradle modules — `rtls-core`, `rtls-offline-sync`, `rtls-websocket`, `rtls-location`, `rtls-client`
- **iOS:** 5 SwiftPM targets — `RTLSCore`, `RTLSLocation`, `RTLSOfflineSync`, `RTLSWebSocket`, `RTLSyncKit` (umbrella)
- **Flutter:** 5 packages — `rtls_core`, `rtls_offline_sync`, `rtls_websocket`, `rtls_location`, `rtls_flutter_unified`
- **Backend:** WebSocket v2 protocol with bidirectional push + `GET /v1/locations/pull` for historical data

This React Native module benefits from the modular native engines without requiring API changes — the JS interface remains the same. Apps that only need a subset of functionality can link fewer native modules to reduce binary size.

For full details, see [MODULAR_ARCHITECTURE.md](../MODULAR_ARCHITECTURE.md).

---

## License

See repository [LICENSE](../LICENSE).
