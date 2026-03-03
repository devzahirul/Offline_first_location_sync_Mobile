import Foundation

/// Controls local data cleanup so the on-device database doesn't grow forever.
public struct RetentionPolicy: Sendable, Equatable {
    /// If set, sent points older than this age are deleted from the local store.
    /// Pending (unsent) points are never deleted by this policy.
    public var sentPointsMaxAge: TimeInterval?

    public init(sentPointsMaxAge: TimeInterval?) {
        self.sentPointsMaxAge = sentPointsMaxAge
    }
}

extension RetentionPolicy {
    public static let keepForever = RetentionPolicy(sentPointsMaxAge: nil)

    /// Pragmatic default: keep local sent points for 7 days, then prune.
    public static let recommended = RetentionPolicy(sentPointsMaxAge: 7 * 24 * 60 * 60)
}

