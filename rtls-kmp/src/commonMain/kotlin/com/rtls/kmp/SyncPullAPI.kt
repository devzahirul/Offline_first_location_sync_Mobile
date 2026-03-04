package com.rtls.kmp

/**
 * Opaque token from server for incremental fetch. Client persists and passes on next fetch.
 */
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

/**
 * Result of a pull (fetch) from server.
 */
data class SyncFetchResult(
    val items: List<LocationPoint>,
    val nextCursor: SyncCursor? = null,
    val serverTimeMs: Long? = null
)

/**
 * Optional: implement for bidirectional sync. If not provided, engine is upload-only.
 */
interface LocationPullAPI {
    suspend fun fetch(since: SyncCursor?): SyncFetchResult
}
