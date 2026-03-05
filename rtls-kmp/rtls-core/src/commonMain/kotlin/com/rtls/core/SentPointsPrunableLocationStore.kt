package com.rtls.core

interface SentPointsPrunableLocationStore : LocationStore {
    suspend fun pruneSentPoints(olderThanRecordedMs: Long)
}
