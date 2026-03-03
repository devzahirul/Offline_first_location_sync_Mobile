# rtls_flutter_example

Example Flutter app for the **rtls_flutter** plugin. One screen: config (base URL, userId, deviceId, token), Configure, Start/Stop tracking, Flush now, and display of pending count and last event.

## Run

From this directory:

```bash
flutter pub get
flutter run
```

- **Android:** The example’s `android/settings.gradle.kts` includes the KMP project (`rtls_kmp`) from the repo (`../../../rtls-kmp`). No extra steps; build and run on a device or emulator. Ensure location permissions are granted when prompted.
- **iOS:** Before building in Xcode, add the **RTLSyncKit** Swift package: File → Add Package Dependencies → add the repo root (path to the repo containing `Package.swift`). Add the **RTLSyncKit** library to the **Runner** app target. Then run `flutter run` or open `ios/Runner.xcworkspace` in Xcode and run.

All components talk to the same backend: `POST /v1/locations/batch`, optional WebSocket at `/v1/ws`.
