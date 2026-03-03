# RTLS Android App

Native Android app (Kotlin) that uses the **rtls-kmp** module for offline-first location sync. Same backend as the iOS and Flutter clients: `POST /v1/locations/batch`, etc.

## Build and run

1. Open in Android Studio or from the command line:
   ```bash
   cd rtls-android-app
   ./gradlew assembleDebug
   ```
2. Install on a device or emulator: `./gradlew installDebug`
3. Set **Base URL** (e.g. `http://10.0.2.2:3000` for emulator), User ID, Device ID, and token, then tap **Configure**.
4. Grant location permission, then tap **Start** to begin tracking. Use **Flush now** to upload pending points immediately.

## Requirements

- Android SDK 21+
- The **rtls-kmp** module is included as a subproject (`../rtls-kmp`). Ensure that path exists when building.
