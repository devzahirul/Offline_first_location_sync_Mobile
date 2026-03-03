package com.rtls.kmp

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

sealed class SyncEngineEvent {
    data class UploadSuccess(val accepted: Int, val rejected: Int) : SyncEngineEvent()
    data class UploadFailed(val message: String) : SyncEngineEvent()
}

class SyncEngine(
    private val store: LocationStore,
    private val api: LocationSyncAPI,
    private val batchSize: Int = 50,
    private val scope: CoroutineScope
) {
    private val _events = MutableSharedFlow<SyncEngineEvent>(extraBufferCapacity = 64)
    val events: SharedFlow<SyncEngineEvent> = _events.asSharedFlow()

    private var flushJob: Job? = null
    private var running = false

    fun start() {
        if (running) return
        running = true
        flushJob = scope.launch {
            while (isActive && running) {
                flush()
                delay(5_000)
            }
        }
    }

    fun stop() {
        running = false
        flushJob?.cancel()
        flushJob = null
    }

    suspend fun flush() {
        val pending = store.fetchPendingPoints(batchSize)
        if (pending.isEmpty()) return
        try {
            val batch = LocationUploadBatch(points = pending)
            val result = api.upload(batch)
            store.markSent(result.acceptedIds, System.currentTimeMillis())
            _events.emit(SyncEngineEvent.UploadSuccess(result.acceptedIds.size, result.rejected.size))
        } catch (e: Exception) {
            _events.emit(SyncEngineEvent.UploadFailed(e.message ?: "Unknown error"))
            store.markFailed(pending.map { it.id }, e.message ?: "Unknown")
        }
    }

    fun notifyNewData() {
        scope.launch { flush() }
    }
}
