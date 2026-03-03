package com.rtls.kmp

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class GeoCoordinate(
    val latitude: Double,
    val longitude: Double
)

@Serializable
data class LocationPoint(
    val id: String,
    val userId: String,
    val deviceId: String,
    @SerialName("recordedAt") val recordedAtMs: Long,
    @SerialName("lat") val lat: Double,
    @SerialName("lng") val lng: Double,
    val horizontalAccuracy: Double? = null,
    val verticalAccuracy: Double? = null,
    val altitude: Double? = null,
    val speed: Double? = null,
    val course: Double? = null
) {
    fun toBatchPoint(): LocationPoint = this
}

@Serializable
data class LocationUploadBatch(
    val schemaVersion: Int = 1,
    val points: List<LocationPoint>
)

@Serializable
data class LocationUploadResult(
    val acceptedIds: List<String>,
    val rejected: List<RejectedPoint> = emptyList(),
    val serverTime: Long? = null
)

@Serializable
data class RejectedPoint(
    val id: String,
    val reason: String
)
