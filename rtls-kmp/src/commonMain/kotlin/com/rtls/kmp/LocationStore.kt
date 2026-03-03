package com.rtls.kmp

interface LocationStore {
    suspend fun insert(points: List<LocationPoint>)
    suspend fun fetchPendingPoints(limit: Int): List<LocationPoint>
    suspend fun pendingCount(): Int
    suspend fun oldestPendingRecordedAt(): Long?
    suspend fun markSent(pointIds: List<String>, sentAtMs: Long)
    suspend fun markFailed(pointIds: List<String>, errorMessage: String)
}
