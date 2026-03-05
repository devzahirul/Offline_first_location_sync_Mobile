import Foundation
import RTLSCore

/// Standalone offline-first sync client. Usable without location or WebSocket packages.
/// Insert data from any source; SyncEngine handles batch upload and optional bidirectional pull.
public actor OfflineSyncClient {
    private let store: SQLiteLocationStore
    private let syncEngine: SyncEngine

    private let eventsStream: AsyncStream<SyncEngineEvent>
    private let continuation: AsyncStream<SyncEngineEvent>.Continuation

    public nonisolated var events: AsyncStream<SyncEngineEvent> { eventsStream }

    public init(
        store: SQLiteLocationStore,
        api: any LocationSyncAPI,
        batchingPolicy: BatchingPolicy = BatchingPolicy(),
        retryPolicy: SyncRetryPolicy = .default,
        retentionPolicy: RetentionPolicy = .recommended,
        network: NetworkMonitor = NetworkMonitor(),
        pullAPI: (any LocationPullAPI)? = nil,
        mergeStrategy: (any LocationMergeStrategy)? = nil,
        pullInterval: TimeInterval? = nil
    ) {
        self.store = store
        self.syncEngine = SyncEngine(
            store: store,
            api: api,
            batchingPolicy: batchingPolicy,
            retryPolicy: retryPolicy,
            retentionPolicy: retentionPolicy,
            network: network,
            pullAPI: pullAPI,
            mergeStrategy: mergeStrategy,
            pullInterval: pullInterval
        )

        let (stream, cont) = AsyncStream<SyncEngineEvent>.makeStream(bufferingPolicy: .bufferingNewest(64))
        self.eventsStream = stream
        self.continuation = cont

        Task { [syncEngine] in
            for await event in syncEngine.events {
                cont.yield(event)
            }
        }
    }

    public func start() async {
        await syncEngine.start()
    }

    public func stop() async {
        await syncEngine.stop()
    }

    /// Insert points from any data source. SyncEngine will batch-upload them.
    public func insert(points: [LocationPoint]) async throws {
        try await store.insert(points: points)
        await syncEngine.notifyNewData()
    }

    public func flushNow(maxBatches: Int? = nil) async {
        await syncEngine.flushNow(maxBatches: maxBatches)
    }

    public func pullNow() async {
        await syncEngine.pullNow()
    }

    public func pendingCount() async throws -> Int {
        try await store.pendingCount()
    }

    public func pendingStats() async throws -> PendingStats {
        try await store.pendingStats()
    }
}
