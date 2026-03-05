package com.rtls.sync

import com.rtls.core.LocationPoint

data class MergeContext(
    val lastSyncAtMs: Long? = null,
    val serverTimeMs: Long? = null
)

sealed class LocationMergeResult {
    data object KeepLocal : LocationMergeResult()
    data object KeepServer : LocationMergeResult()
    data class Use(val point: LocationPoint) : LocationMergeResult()
}

interface LocationMergeStrategy {
    fun resolve(
        local: LocationPoint?,
        server: LocationPoint,
        context: MergeContext
    ): LocationMergeResult
}
