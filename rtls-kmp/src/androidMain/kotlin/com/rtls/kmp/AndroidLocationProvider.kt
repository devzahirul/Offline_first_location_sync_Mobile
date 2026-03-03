package com.rtls.kmp

import android.content.Context
import android.location.Location
import android.os.Looper
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import java.util.UUID

class AndroidLocationProvider(private val context: Context) {

    private val client: FusedLocationProviderClient by lazy {
        LocationServices.getFusedLocationProviderClient(context)
    }

    fun locationFlow(userId: String, deviceId: String): Flow<LocationPoint> = callbackFlow {
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10_000)
            .setMinUpdateIntervalMillis(5_000)
            .setMinUpdateDistanceMeters(10f)
            .build()
        val callback = object : LocationCallback() {
            override fun onLocationResult(result: com.google.android.gms.location.LocationResult) {
                result.lastLocation?.let { loc ->
                    trySend(loc.toLocationPoint(userId, deviceId))
                }
            }
        }
        try {
            client.requestLocationUpdates(request, callback, Looper.getMainLooper())
        } catch (e: SecurityException) {
            close(e)
        }
        awaitClose { client.removeLocationUpdates(callback) }
    }

    private fun Location.toLocationPoint(userId: String, deviceId: String): LocationPoint =
        LocationPoint(
            id = UUID.randomUUID().toString(),
            userId = userId,
            deviceId = deviceId,
            recordedAtMs = System.currentTimeMillis(),
            lat = latitude,
            lng = longitude,
            horizontalAccuracy = if (hasAccuracy()) accuracy.toDouble() else null,
            verticalAccuracy = null,
            altitude = if (hasAltitude()) altitude.toDouble() else null,
            speed = if (hasSpeed()) speed.toDouble().takeIf { it >= 0 } else null,
            course = if (hasBearing()) bearing.toDouble().takeIf { it >= 0 } else null
        )
}
