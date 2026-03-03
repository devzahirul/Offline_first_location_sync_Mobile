// swift-tools-version: 5.9
//
// When this repo is added as a Swift package (Git URL), only this file and the
// targets below (Sources/RTLSCore, RTLSData, RTLSSync, RTLSyncKit, RTLSPlatformiOS)
// are built and linked. The rest of the repo (Android, React Native, Flutter,
// backend, dashboard) is not used by Swift Package Manager.

import PackageDescription

let package = Package(
    name: "RTLSyncKit",
    platforms: [
        .iOS(.v15),
        // Allows `swift test` on macOS while keeping iOS as the primary target.
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "RTLSyncKit",
            targets: ["RTLSyncKit"]
        ),
    ],
    targets: [
        .target(
            name: "RTLSCore"
        ),
        .target(
            name: "RTLSPlatformiOS",
            dependencies: ["RTLSCore"],
            linkerSettings: [
                .linkedFramework("CoreLocation"),
            ]
        ),
        .target(
            name: "RTLSData",
            dependencies: ["RTLSCore"],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .target(
            name: "RTLSSync",
            dependencies: ["RTLSCore", "RTLSData"],
            linkerSettings: [
                .linkedFramework("Network"),
            ]
        ),
        .target(
            name: "RTLSyncKit",
            dependencies: ["RTLSCore", "RTLSPlatformiOS", "RTLSData", "RTLSSync"],
            linkerSettings: [
                .linkedFramework("BackgroundTasks", .when(platforms: [.iOS])),
            ]
        ),
        .testTarget(
            name: "RTLSCoreTests",
            dependencies: ["RTLSCore"]
        ),
    ]
)
