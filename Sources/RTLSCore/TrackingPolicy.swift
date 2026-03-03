import Foundation

public enum TrackingPolicy: Equatable, Sendable {
    /// Record at most once per interval (best-effort; depends on CoreLocation delivery cadence).
    case time(interval: TimeInterval)
    /// Record when moved at least N meters from the last recorded point.
    case distance(meters: Double)

    public static let `default` = TrackingPolicy.distance(meters: 25)
}

