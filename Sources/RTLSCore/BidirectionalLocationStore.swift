import Foundation

/// Store that supports applying server-fetched items to a local replica (bidirectional sync).
/// When pull is enabled, the engine uses a store conforming to this protocol.
public protocol BidirectionalLocationStore: LocationStore, Sendable {
    /// Apply server-fetched items to local replica. If item id exists locally (pending or replica),
    /// mergeStrategy is used when provided; otherwise server-wins.
    /// - Parameters:
    ///   - serverTime: Optional server time from the fetch result, passed to merge context.
    ///   - lastSyncAt: Optional last successful pull time, passed to merge context.
    func applyServerChanges(
        _ items: [LocationPoint],
        mergeStrategy: (any LocationMergeStrategy)?,
        serverTime: Date?,
        lastSyncAt: Date?
    ) async throws

    /// Last cursor returned by server from previous fetch. Nil before first pull.
    func getLastPullCursor() async throws -> SyncCursor?

    /// Persist cursor after successful pull for next fetch(since:).
    func setLastPullCursor(_ cursor: SyncCursor?) async throws
}
