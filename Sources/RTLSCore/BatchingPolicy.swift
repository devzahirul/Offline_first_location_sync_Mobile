import Foundation

public struct BatchingPolicy: Equatable, Sendable {
    /// Upload at most this many points in one request.
    public var maxBatchSize: Int

    /// Periodically flush pending points while tracking is running.
    public var flushInterval: TimeInterval

    /// Flush when the oldest pending point is older than this (when network is available).
    public var maxBatchAge: TimeInterval

    public init(
        maxBatchSize: Int = 50,
        flushInterval: TimeInterval = 10,
        maxBatchAge: TimeInterval = 60
    ) {
        self.maxBatchSize = maxBatchSize
        self.flushInterval = flushInterval
        self.maxBatchAge = maxBatchAge
    }
}

