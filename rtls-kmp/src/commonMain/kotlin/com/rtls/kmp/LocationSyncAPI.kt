package com.rtls.kmp

interface LocationSyncAPI {
    suspend fun upload(batch: LocationUploadBatch): LocationUploadResult
}
