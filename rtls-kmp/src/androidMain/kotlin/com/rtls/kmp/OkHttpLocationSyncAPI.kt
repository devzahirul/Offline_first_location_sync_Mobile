package com.rtls.kmp

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class OkHttpLocationSyncAPI(
    private val baseUrl: String,
    private val tokenProvider: AuthTokenProvider,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()
) : LocationSyncAPI {

    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun upload(batch: LocationUploadBatch): LocationUploadResult = withContext(Dispatchers.IO) {
        val token = tokenProvider.accessToken()
        val url = baseUrl.trimEnd('/') + "/v1/locations/batch"
        val body = json.encodeToString(batch).toRequestBody("application/json; charset=utf-8".toMediaType())
        val request = Request.Builder()
            .url(url)
            .post(body)
            .addHeader("Authorization", "Bearer $token")
            .addHeader("Content-Type", "application/json")
            .build()
        val response = client.newCall(request).execute()
        if (!response.isSuccessful) {
            throw RuntimeException("Upload failed: ${response.code} ${response.body?.string()}")
        }
        val raw = response.body?.string() ?: throw RuntimeException("Empty response")
        json.decodeFromString<LocationUploadResult>(raw)
    }
}
