package com.rtls.sync

import com.rtls.core.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.SharedFlow

/**
 * Standalone offline-first sync client. Usable without location or WebSocket packages.
 * Insert data from any source; SyncEngine handles batch upload and optional bidirectional pull.
 */
class OfflineSyncClient(
    private val store: LocationStore,
    private val api: LocationSyncAPI,
    private val batchingPolicy: BatchingPolicy = BatchingPolicy(),
    private val retryPolicy: SyncRetryPolicy = SyncRetryPolicy.Default,
    private val retentionPolicy: RetentionPolicy = RetentionPolicy.Recommended,
    private val networkMonitor: NetworkMonitor? = null,
    private val pullAPI: LocationPullAPI? = null,
    private val mergeStrategy: LocationMergeStrategy? = null,
    private val pullIntervalSeconds: Long? = null,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
) {
    private val engine = SyncEngine(
        store = store,
        api = api,
        batching = batchingPolicy,
        retryPolicy = retryPolicy,
        retentionPolicy = retentionPolicy,
        networkMonitor = networkMonitor,
        scope = scope,
        pullAPI = pullAPI,
        mergeStrategy = mergeStrategy,
        pullIntervalSeconds = pullIntervalSeconds
    )

    val events: SharedFlow<SyncEngineEvent> = engine.events

    fun start() = engine.start()
    fun stop() = engine.stop()

    suspend fun insert(points: List<LocationPoint>) {
        store.insert(points)
        engine.notifyNewData()
    }

    suspend fun flushNow(maxBatches: Int? = null) = engine.flushNow(maxBatches)
    suspend fun pullNow() = engine.pullNow()

    suspend fun pendingCount(): Int = store.pendingCount()
    suspend fun pendingStats(): PendingStats = store.pendingStats()
}
