package com.rtls.core

interface LocationSyncAPI {
    suspend fun upload(batch: LocationUploadBatch): LocationUploadResult
}
