package com.rtls.sync

import com.rtls.core.LocationPoint
import com.rtls.core.LocationStore

interface BidirectionalLocationStore : LocationStore {
    suspend fun applyServerChanges(
        items: List<LocationPoint>,
        mergeStrategy: LocationMergeStrategy?,
        serverTimeMs: Long?,
        lastSyncAtMs: Long?
    )
    suspend fun getLastPullCursor(): SyncCursor?
    suspend fun setLastPullCursor(cursor: SyncCursor?)
}
