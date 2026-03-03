import Foundation
import RTLSyncKit

enum DemoDefaults {
    static let suite = UserDefaults.standard

    static let baseURL = "rtls.base_url"
    static let accessToken = "rtls.access_token"
    static let userId = "rtls.user_id"
    static let deviceId = "rtls.device_id"

    static let policyType = "rtls.policy_type" // "distance" | "time"
    static let distanceMeters = "rtls.distance_meters"
    static let timeIntervalSeconds = "rtls.time_interval_seconds"

    static let batchMaxSize = "rtls.batch_max_size"
    static let flushIntervalSeconds = "rtls.flush_interval_seconds"
    static let maxBatchAgeSeconds = "rtls.max_batch_age_seconds"

    /// Persisted so we can resume tracking when app is reopened.
    static let wasTracking = "rtls.was_tracking"
    /// Use significant-change location (can wake app after terminate; ~500m updates).
    static let useSignificantLocationChanges = "rtls.use_significant_location_changes"
}

struct DemoSettings: Equatable {
    enum PolicyType: String, CaseIterable {
        case distance
        case time
    }

    var baseURL: String
    var accessToken: String
    var userId: String
    var deviceId: String

    var policyType: PolicyType
    var distanceMeters: Double
    var timeIntervalSeconds: Double

    var batchMaxSize: Int
    var flushIntervalSeconds: Double
    var maxBatchAgeSeconds: Double
    var useSignificantLocationChanges: Bool

    static func ensureDefaults() {
        let d = DemoDefaults.suite

        if d.string(forKey: DemoDefaults.baseURL) == nil {
            d.set("http://192.168.0.103:3000", forKey: DemoDefaults.baseURL)
        }
        if d.string(forKey: DemoDefaults.accessToken) == nil {
            d.set("", forKey: DemoDefaults.accessToken)
        }
        if d.string(forKey: DemoDefaults.userId) == nil {
            d.set("user_123", forKey: DemoDefaults.userId)
        }
        if d.string(forKey: DemoDefaults.deviceId) == nil {
            d.set(UUID().uuidString, forKey: DemoDefaults.deviceId)
        }
        if d.string(forKey: DemoDefaults.policyType) == nil {
            d.set(PolicyType.distance.rawValue, forKey: DemoDefaults.policyType)
        }

        if d.object(forKey: DemoDefaults.distanceMeters) == nil {
            d.set(25.0, forKey: DemoDefaults.distanceMeters)
        }
        if d.object(forKey: DemoDefaults.timeIntervalSeconds) == nil {
            d.set(5.0, forKey: DemoDefaults.timeIntervalSeconds)
        }

        if d.object(forKey: DemoDefaults.batchMaxSize) == nil {
            d.set(50, forKey: DemoDefaults.batchMaxSize)
        }
        if d.object(forKey: DemoDefaults.flushIntervalSeconds) == nil {
            d.set(10.0, forKey: DemoDefaults.flushIntervalSeconds)
        }
        if d.object(forKey: DemoDefaults.maxBatchAgeSeconds) == nil {
            d.set(60.0, forKey: DemoDefaults.maxBatchAgeSeconds)
        }
        if d.object(forKey: DemoDefaults.useSignificantLocationChanges) == nil {
            d.set(false, forKey: DemoDefaults.useSignificantLocationChanges)
        }
    }

    static func load() -> DemoSettings {
        ensureDefaults()

        let d = DemoDefaults.suite
        let policy = PolicyType(rawValue: d.string(forKey: DemoDefaults.policyType) ?? "") ?? .distance

        return DemoSettings(
            baseURL: d.string(forKey: DemoDefaults.baseURL) ?? "http://192.168.0.103:3000",
            accessToken: d.string(forKey: DemoDefaults.accessToken) ?? "",
            userId: d.string(forKey: DemoDefaults.userId) ?? "user_123",
            deviceId: d.string(forKey: DemoDefaults.deviceId) ?? UUID().uuidString,
            policyType: policy,
            distanceMeters: d.double(forKey: DemoDefaults.distanceMeters),
            timeIntervalSeconds: d.double(forKey: DemoDefaults.timeIntervalSeconds),
            batchMaxSize: max(1, d.integer(forKey: DemoDefaults.batchMaxSize)),
            flushIntervalSeconds: max(1.0, d.double(forKey: DemoDefaults.flushIntervalSeconds)),
            maxBatchAgeSeconds: max(1.0, d.double(forKey: DemoDefaults.maxBatchAgeSeconds)),
            useSignificantLocationChanges: d.bool(forKey: DemoDefaults.useSignificantLocationChanges)
        )
    }

    func save() {
        let d = DemoDefaults.suite
        d.set(baseURL, forKey: DemoDefaults.baseURL)
        d.set(accessToken, forKey: DemoDefaults.accessToken)
        d.set(userId, forKey: DemoDefaults.userId)
        d.set(deviceId, forKey: DemoDefaults.deviceId)
        d.set(policyType.rawValue, forKey: DemoDefaults.policyType)
        d.set(distanceMeters, forKey: DemoDefaults.distanceMeters)
        d.set(timeIntervalSeconds, forKey: DemoDefaults.timeIntervalSeconds)
        d.set(batchMaxSize, forKey: DemoDefaults.batchMaxSize)
        d.set(flushIntervalSeconds, forKey: DemoDefaults.flushIntervalSeconds)
        d.set(maxBatchAgeSeconds, forKey: DemoDefaults.maxBatchAgeSeconds)
        d.set(useSignificantLocationChanges, forKey: DemoDefaults.useSignificantLocationChanges)
    }

    func makeClientConfiguration() throws -> LocationSyncClientConfiguration {
        guard let baseURL = URL(string: baseURL) else {
            throw NSError(domain: "DemoSettings", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid base URL"])
        }

        let dbURL = try LocationSyncClientConfiguration.defaultDatabaseURL(directoryName: "RealTimeLocationUpdateBackground")

        let policy: TrackingPolicy
        switch policyType {
        case .distance:
            policy = .distance(meters: max(1, distanceMeters))
        case .time:
            policy = .time(interval: max(1, timeIntervalSeconds))
        }

        let batching = BatchingPolicy(
            maxBatchSize: max(1, batchMaxSize),
            flushInterval: max(1, flushIntervalSeconds),
            maxBatchAge: max(1, maxBatchAgeSeconds)
        )

        let token = accessToken
        let tokenProvider = AuthTokenProvider { token }

        var locationConfig = LocationProvider.Configuration()
        locationConfig.allowsBackgroundLocationUpdates = true
        locationConfig.pausesLocationUpdatesAutomatically = false
        locationConfig.showsBackgroundLocationIndicator = true
        locationConfig.useSignificantLocationChanges = useSignificantLocationChanges

        return LocationSyncClientConfiguration(
            baseURL: baseURL,
            authTokenProvider: tokenProvider,
            userId: userId,
            deviceId: deviceId,
            trackingPolicy: policy,
            batchingPolicy: batching,
            retryPolicy: .default,
            retentionPolicy: .recommended,
            databaseURL: dbURL,
            locationProviderConfiguration: locationConfig
        )
    }
}
