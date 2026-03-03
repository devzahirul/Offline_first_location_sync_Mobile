import Foundation

public protocol SentPointsPrunableLocationStore: Sendable {
    /// Deletes points that have been successfully sent and are older than the provided cutoff date.
    func pruneSentPoints(olderThan cutoff: Date) async throws
}

