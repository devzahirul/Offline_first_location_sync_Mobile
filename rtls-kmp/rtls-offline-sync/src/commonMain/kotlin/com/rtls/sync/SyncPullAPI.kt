package com.rtls.sync

import com.rtls.core.LocationPoint

data class SyncCursor(val value: ByteArray) {
    constructor(string: String) : this(string.encodeToByteArray())
    fun stringValue(): String = value.decodeToString()
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is SyncCursor) return false
        return value.contentEquals(other.value)
    }
    override fun hashCode(): Int = value.contentHashCode()
}

data class SyncFetchResult(
    val items: List<LocationPoint>,
    val nextCursor: SyncCursor? = null,
    val serverTimeMs: Long? = null
)

interface LocationPullAPI {
    suspend fun fetch(since: SyncCursor?): SyncFetchResult
}
