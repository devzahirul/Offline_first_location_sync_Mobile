package com.rtls.kmp

/**
 * Context passed to merge strategy when resolving a conflict.
 */
data class MergeContext(
    val lastSyncAtMs: Long? = null,
    val serverTimeMs: Long? = null
)

/**
 * Result of resolving a conflict: keep local, keep server, or use a merged item.
 */
sealed class LocationMergeResult {
    data object KeepLocal : LocationMergeResult()
    data object KeepServer : LocationMergeResult()
    data class Use(val point: LocationPoint) : LocationMergeResult()
}

/**
 * Optional. If not provided, default is server-wins for pull (overwrite local with server).
 */
interface LocationMergeStrategy {
    fun resolve(
        local: LocationPoint?,
        server: LocationPoint,
        context: MergeContext
    ): LocationMergeResult
}
