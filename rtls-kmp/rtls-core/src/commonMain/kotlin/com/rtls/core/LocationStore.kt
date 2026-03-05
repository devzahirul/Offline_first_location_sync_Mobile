package com.rtls.core

data class PendingStats(val count: Int, val oldestRecordedAtMs: Long?)

interface LocationStore {
    suspend fun insert(points: List<LocationPoint>)
    suspend fun fetchPendingPoints(limit: Int): List<LocationPoint>
    suspend fun pendingCount(): Int
    suspend fun oldestPendingRecordedAt(): Long?
    suspend fun pendingStats(): PendingStats = PendingStats(pendingCount(), oldestPendingRecordedAt())
    suspend fun markSent(pointIds: List<String>, sentAtMs: Long)
    suspend fun markFailed(pointIds: List<String>, errorMessage: String)
}
