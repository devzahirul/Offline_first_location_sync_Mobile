import Combine
import CoreLocation
import Foundation
import RTLSyncKit

@MainActor
final class LocationSyncDemoViewModel: ObservableObject {
    @Published private(set) var authorization: LocationAuthorization = .notDetermined
    @Published private(set) var isTracking = false
    @Published private(set) var lastRecorded: LocationPoint?
    @Published private(set) var lastSyncMessage: String = "—"
    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var oldestPendingRecordedAt: Date?
    @Published private(set) var pendingPointsList: [LocationPoint] = []
    @Published private(set) var errorMessage: String?

    @Published var isSubscriberRunning = false
    @Published var subscriberUserId: String = ""
    @Published private(set) var lastSubscribedPoint: LocationPoint?

    @Published private(set) var recordedPath: [CLLocationCoordinate2D] = []
    @Published private(set) var subscribedPath: [CLLocationCoordinate2D] = []

    @Published private(set) var logs: [String] = []

    @Published private(set) var isClientReady = false

    private var client: LocationSyncClient?
    private var eventsTask: Task<Void, Never>?
    private var subscribeTask: Task<Void, Never>?
    private var lifecycleHooks: RTLSAppLifecycleHooks?
    private var noLocationCheckTask: Task<Void, Never>?
    private var receivedLocationSinceTrackingStarted = false

    private let maxMapPoints = 500

    func start() {
        rebuildClient()
    }

    func rebuildClient() {
        isClientReady = false
        noLocationCheckTask?.cancel()
        noLocationCheckTask = nil
        eventsTask?.cancel()
        eventsTask = nil

        subscribeTask?.cancel()
        subscribeTask = nil
        isSubscriberRunning = false
        lastSubscribedPoint = nil
        subscribedPath = []

        lifecycleHooks?.stop()
        lifecycleHooks = nil

        recordedPath = []

        Task { @MainActor in
            do {
                let settings = DemoSettings.load()
                let cfg = try settings.makeClientConfiguration()

                let client = try await LocationSyncClient(configuration: cfg)
                self.client = client
                self.isClientReady = true

                // Optional: schedule BG processing + flush on app lifecycle transitions.
                let bgCfg = BackgroundProcessingConfiguration(taskIdentifier: BackgroundTaskIdentifiers.locationSync)
                let hooks = RTLSAppLifecycleHooks(client: client, backgroundProcessing: bgCfg)
                hooks.start()
                self.lifecycleHooks = hooks

                log("Client ready. baseURL=\(cfg.baseURL.absoluteString) userId=\(cfg.userId) deviceId=\(cfg.deviceId)")
                await loadInitialMapPath(from: client)
                await refreshStats()
                await bindEvents(from: client)
                if DemoDefaults.suite.bool(forKey: DemoDefaults.wasTracking) {
                    await client.requestAlwaysAuthorization()
                    await client.startTracking()
                    log("Tracking resumed (was on before app closed)")
                }
            } catch {
                self.client = nil
                self.isClientReady = false
                self.errorMessage = String(describing: error)
                log("Client init error: \(String(describing: error))")
            }
        }
    }

    func requestAlwaysAuthorization() {
        guard let client else { return }
        Task { await client.requestAlwaysAuthorization() }
    }

    func requestWhenInUseAuthorization() {
        guard let client else { return }
        Task { await client.requestWhenInUseAuthorization() }
    }

    func toggleTracking() {
        guard let client else { return }
        Task { @MainActor in
            if isTracking {
                await client.stopTracking()
            } else {
                await client.requestAlwaysAuthorization()
                await client.startTracking()
            }
        }
    }

    func flushNow() {
        guard let client else { return }
        Task { await client.flushNow() }
    }

    func refreshStats() async {
        guard let client else { return }
        let stats = await client.stats()
        pendingCount = max(0, stats.pendingCount)
        oldestPendingRecordedAt = stats.oldestPendingRecordedAt
    }

    func loadPendingPoints() async {
        guard let client else { return }
        let list = await client.pendingPoints(limit: 500)
        pendingPointsList = list
    }

    /// Call when view appears so status (pending count, etc.) is up to date after reopen.
    func refreshIfReady() {
        guard client != nil else { return }
        Task { @MainActor in
            await refreshStats()
        }
    }

    func startSubscriber() {
        guard let client else { return }
        let userId = subscriberUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else { return }

        subscribeTask?.cancel()
        subscribeTask = Task { @MainActor in
            isSubscriberRunning = true
            lastSubscribedPoint = nil
            subscribedPath = []
            log("Subscriber started for userId=\(userId)")

            do {
                let stream = await client.subscribeToUserLocations(userId: userId)
                for try await point in stream {
                    lastSubscribedPoint = point
                    appendToPath(&subscribedPath, coordinate: point.coordinate)
                    log("Subscribed: \(format(point: point))")
                }
            } catch {
                log("Subscriber error: \(String(describing: error))")
            }

            isSubscriberRunning = false
        }
    }

    func stopSubscriber() {
        subscribeTask?.cancel()
        subscribeTask = nil
        isSubscriberRunning = false
        log("Subscriber stopped")
    }

    func clearMapPaths() {
        recordedPath = []
        subscribedPath = []
    }

    // MARK: - Private

    private func bindEvents(from client: LocationSyncClient) async {
        eventsTask?.cancel()
        eventsTask = Task { @MainActor in
            for await e in client.events {
                handle(event: e)
            }
        }
    }

    private func handle(event: LocationSyncClientEvent) {
        switch event {
        case .authorizationChanged(let auth):
            authorization = auth
            log("Auth: \(auth)")

        case .trackingStarted:
            isTracking = true
            receivedLocationSinceTrackingStarted = false
            DemoDefaults.suite.set(true, forKey: DemoDefaults.wasTracking)
            log("Tracking started")
            scheduleNoLocationCheckIfNeeded()

        case .trackingStopped:
            noLocationCheckTask?.cancel()
            noLocationCheckTask = nil
            isTracking = false
            receivedLocationSinceTrackingStarted = false
            DemoDefaults.suite.set(false, forKey: DemoDefaults.wasTracking)
            log("Tracking stopped")

        case .recorded(let point):
            receivedLocationSinceTrackingStarted = true
            noLocationCheckTask?.cancel()
            noLocationCheckTask = nil
            lastRecorded = point
            errorMessage = nil
            appendToPath(&recordedPath, coordinate: point.coordinate)
            log("Recorded: \(format(point: point))")
            Task { @MainActor in await refreshStats() }

        case .syncEvent(let se):
            switch se {
            case .didUpload(let accepted, let rejected):
                lastSyncMessage = "uploaded accepted=\(accepted) rejected=\(rejected)"
                log("Sync: \(lastSyncMessage)")
                Task { @MainActor in await refreshStats() }
            case .uploadFailed(let msg):
                lastSyncMessage = "upload failed: \(msg)"
                log("Sync: \(lastSyncMessage)")
            }

        case .error(let msg):
            errorMessage = msg
            log("Error: \(msg)")
        }
    }

    private func log(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        logs.insert("[\(ts)] \(message)", at: 0)
        if logs.count > 250 { logs.removeLast(logs.count - 250) }
    }

    private func loadInitialMapPath(from client: LocationSyncClient) async {
        let points = await client.recentPoints(limit: maxMapPoints)
        recordedPath = points.map { CLLocationCoordinate2D(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
        lastRecorded = points.last
    }

    private func appendToPath(_ path: inout [CLLocationCoordinate2D], coordinate: GeoCoordinate) {
        path.append(CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude))
        if path.count > maxMapPoints {
            path.removeFirst(path.count - maxMapPoints)
        }
    }

    private func format(point: LocationPoint) -> String {
        let lat = String(format: "%.5f", point.coordinate.latitude)
        let lng = String(format: "%.5f", point.coordinate.longitude)
        let acc = point.horizontalAccuracy.map { String(format: "%.0fm", $0) } ?? "—"
        return "(\(lat), \(lng)) acc=\(acc) t=\(point.recordedAt)"
    }

    /// If continuous mode and no location received within 60s, reset tracking state so button shows Start again.
    private func scheduleNoLocationCheckIfNeeded() {
        guard !DemoDefaults.suite.bool(forKey: DemoDefaults.useSignificantLocationChanges) else { return }
        noLocationCheckTask?.cancel()
        noLocationCheckTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            guard !Task.isCancelled, isTracking, !receivedLocationSinceTrackingStarted, client != nil else { return }
            DemoDefaults.suite.set(false, forKey: DemoDefaults.wasTracking)
            isTracking = false
            if let client {
                Task { await client.stopTracking() }
            }
            errorMessage = "No location received. Check Always permission and try again."
            log("Stopped: no location updates in 60s")
        }
    }
}
