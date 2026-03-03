# rtls-react-native

**React Native native module** for offline-first location sync on **iOS and Android**. On iOS it uses the [RTLSyncKit](https://github.com/devzahirul/Offline_first_location_sync_iOS) Swift engine; on Android it uses the shared [rtls-kmp](../rtls-kmp/README.md) Kotlin module. Same JavaScript API on both platforms; same backend contract.

---

## Overview

- **iOS:** Native module (Swift) wrapping RTLSyncKit. Requires linking the Swift package in Xcode.
- **Android:** Native module (Kotlin) wrapping **rtls-kmp** (same sync engine as the native Android app and Flutter on Android). Requires including the `rtls-kmp` project in the app’s Gradle build and location permissions.
- **Backend:** Same API on both: `POST /v1/locations/batch`, `GET /v1/locations/latest?userId=`, WebSocket `/v1/ws`. JWT in `Authorization` where required.
- **API surface:** Configure (base URL, userId, deviceId, access token), requestAlwaysAuthorization, startTracking, stopTracking, getStats, flushNow, and event listeners (RECORDED, SYNC_EVENT, ERROR, AUTHORIZATION_CHANGED, TRACKING_STARTED, TRACKING_STOPPED).

---

## Installation

From the repo root (or the directory that contains the Swift package and this package):

```bash
npm install file:../rtls-react-native
# or
yarn add file:../rtls-react-native
```

Or in `package.json`:

```json
"dependencies": {
  "rtls-react-native": "file:../rtls-react-native"
}
```

Then run `npm install` (or `yarn`) in the app root.

---

## iOS setup

### 1. Native module and CocoaPods

If your app uses CocoaPods, run from the app’s `ios/` directory:

```bash
cd ios
pod install
```

The package ships with a podspec so the native code is linked.

### 2. Link the RTLSyncKit Swift package

The module **imports RTLSyncKit**; the app target must include the Swift package.

1. Open your app’s **`.xcworkspace`** in Xcode (e.g. `ios/YourApp.xcworkspace`).
2. **File → Add Package Dependencies…**
3. Add the package that contains **Package.swift** (this repo root, or the Git URL).
4. Add the **RTLSyncKit** library to your **app target** (General → Frameworks, Libraries, and Embedded Content → + → RTLSyncKit).

Without this step, the build will fail with “Unable to find module 'RTLSyncKit'”.

### 3. Rebuild

```bash
npx react-native run-ios
```

Or build from Xcode.

---

## Android setup

### 1. Include the rtls-kmp project

The Android native code **depends on the rtls-kmp module**. Your app’s Android build must include it.

In your app’s **`android/settings.gradle`** (or `settings.gradle.kts`), add (adjust the path so it points to the **rtls-kmp** folder in your repo):

**Groovy:**

```groovy
include ':app'
include ':rtls_kmp'
project(':rtls_kmp').projectDir = file('<path-to-rtls-kmp>')
```

**Kotlin DSL:**

```kotlin
include(":app")
include(":rtls_kmp")
project(":rtls_kmp").projectDir = file("<path-to-rtls-kmp>")
```

Example: if your repo layout is `myrepo/rtls-kmp` and `myrepo/MyApp/android/`, then from `MyApp/android/` use `file("../../rtls-kmp")`.

### 2. Location permissions

In **`android/app/src/main/AndroidManifest.xml`**:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

Request these at runtime before calling `startTracking()` (e.g. with `react-native-permissions` or similar).

### 3. Rebuild

```bash
npx react-native run-android
```

---

## JavaScript / TypeScript API

### Configure (required before tracking)

```ts
import RTLSync from 'rtls-react-native';

await RTLSync.configure({
  baseURL: 'https://your-backend.com',
  userId: 'user-1',
  deviceId: 'device-1',
  accessToken: 'your-jwt-or-token',
});
```

### Permissions and tracking

```ts
await RTLSync.requestAlwaysAuthorization();  // for background updates (iOS)
await RTLSync.startTracking();
// ...
await RTLSync.stopTracking();
```

### Stats and flush

```ts
const stats = await RTLSync.getStats();
// { pendingCount: number, oldestPendingRecordedAt: number | null }
await RTLSync.flushNow();
```

### Events

Subscribe to events (event names and payloads aligned with RTLSyncKit):

```ts
import RTLSync, { RTLSyncEvents } from 'rtls-react-native';

const sub1 = RTLSync.addEventListener('RECORDED', (point) => {
  console.log('Recorded', point);
  // { id, userId, deviceId, recordedAt, lat, lng, ... }
});

const sub2 = RTLSync.addEventListener('SYNC_EVENT', (e) => {
  console.log('Sync', e);
  // { type: 'uploadSucceeded' | 'uploadFailed', accepted?, rejected?, message? }
});

// cleanup
sub1.remove();
sub2.remove();
```

**Event names:** `RECORDED`, `SYNC_EVENT`, `ERROR`, `AUTHORIZATION_CHANGED`, `TRACKING_STARTED`, `TRACKING_STOPPED`.

---

## Backend contract (reference)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST` | `/v1/locations/batch` | Upload batches; JWT in `Authorization: Bearer <token>` |
| `GET` | `/v1/locations/latest?userId=…` | Latest point for user |
| WebSocket | `/v1/ws` | Subscribe; server broadcasts location updates |

See the repo’s [backend-nodejs/README.md](../backend-nodejs/README.md) and root [README.md](../README.md) for full API and run instructions.

---

## Example app

The repository includes a minimal React Native app that uses this module: [rtls-mobile-example/README.md](../rtls-mobile-example/README.md). Use it for install order, iOS (Swift package + `pod install`), and Android (include `rtls_kmp` in `settings.gradle`).

---

## License

See repository [LICENSE](../LICENSE).
