import Foundation

/// Exponential backoff policy for upload retries.
public struct SyncRetryPolicy: Sendable, Equatable {
    /// Delay used for the first failure.
    public var baseDelay: TimeInterval

    /// Cap for exponential backoff.
    public var maxDelay: TimeInterval

    /// Randomization factor to avoid thundering herds. Range: 0...1.
    public var jitterFraction: Double

    public init(
        baseDelay: TimeInterval = 2,
        maxDelay: TimeInterval = 120,
        jitterFraction: Double = 0.2
    ) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitterFraction = jitterFraction
    }
}

extension SyncRetryPolicy {
    public static let `default` = SyncRetryPolicy()

    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let exp = pow(2.0, Double(attempt - 1))
        return min(maxDelay, baseDelay * exp)
    }
}

