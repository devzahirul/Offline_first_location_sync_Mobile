# Offline_first_location_sync_iOS

Offline-first real-time location sync for iOS. Capture and sync location updates in the background, with support for deferred upload when back online.

## Project structure

- **RealTimeLocationUpdateBackground** – iOS app (Swift) with background location updates and demo UI
- **Sources/RTLSyncKit** – Sync logic and app lifecycle hooks
- **Sources/RTLSPlatformiOS** – iOS location provider
- **rtls-dashboard** – Web dashboard (React + TypeScript) to view locations
- **backend-nodejs** – Node.js backend for receiving and serving location data

## Requirements

- Xcode (iOS app)
- Node.js (backend & dashboard)
- iOS device or simulator

## Getting started

1. Open `RealTimeLocationUpdateBackground/RealTimeLocationUpdateBackground.xcodeproj` in Xcode.
2. Run the iOS app on a device or simulator.
3. Start the backend and dashboard from their directories as needed.

## License

See repository for details.
