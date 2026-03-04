package com.rtls.kmp

/**
 * Store that supports applying server-fetched items to a local replica (bidirectional sync).
 * When pull is enabled, the engine uses a store conforming to this interface.
 */
interface BidirectionalLocationStore : LocationStore {
    /**
     * Apply server-fetched items to local replica. If item id exists locally (pending or replica),
     * mergeStrategy is used when provided; otherwise server-wins.
     */
    suspend fun applyServerChanges(
        items: List<LocationPoint>,
        mergeStrategy: LocationMergeStrategy?,
        serverTimeMs: Long?,
        lastSyncAtMs: Long?
    )

    suspend fun getLastPullCursor(): SyncCursor?

    suspend fun setLastPullCursor(cursor: SyncCursor?)
}
