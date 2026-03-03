import Foundation

public struct LocationRecordingDecider: Sendable, Equatable {
    public var policy: TrackingPolicy
    public private(set) var lastRecordedAt: Date?
    public private(set) var lastRecordedCoordinate: GeoCoordinate?

    public init(
        policy: TrackingPolicy,
        lastRecordedAt: Date? = nil,
        lastRecordedCoordinate: GeoCoordinate? = nil
    ) {
        self.policy = policy
        self.lastRecordedAt = lastRecordedAt
        self.lastRecordedCoordinate = lastRecordedCoordinate
    }

    public func shouldRecord(sampleAt: Date, coordinate: GeoCoordinate) -> Bool {
        switch policy {
        case .time(let interval):
            guard interval > 0 else { return true }
            guard let lastRecordedAt else { return true }
            return sampleAt.timeIntervalSince(lastRecordedAt) >= interval

        case .distance(let meters):
            guard meters > 0 else { return true }
            guard let lastRecordedCoordinate else { return true }
            return coordinate.distance(to: lastRecordedCoordinate) >= meters
        }
    }

    public mutating func markRecorded(sampleAt: Date, coordinate: GeoCoordinate) {
        lastRecordedAt = sampleAt
        lastRecordedCoordinate = coordinate
    }
}
