package com.rtls.rtls_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.location.Location
import com.google.android.gms.location.LocationResult
import com.rtls.kmp.LocationPoint
import com.rtls.kmp.SqliteLocationStore
import kotlinx.coroutines.runBlocking
import java.util.UUID

/**
 * Receives location updates delivered by the system via PendingIntent when using
 * FusedLocationProviderClient.requestLocationUpdates(request, PendingIntent).
 * This allows location to be recorded even after the app process has been killed:
 * the system starts the process and delivers to this receiver, which inserts into
 * the same SQLite store used by the sync engine. Upload happens on next app launch
 * (lifecycle flush) or when the app is in foreground (plugin calls flushNow on
 * local broadcast).
 */
class RtlsLocationBroadcastReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (!LocationResult.hasResult(intent)) return
        val result = LocationResult.extractResult(intent) ?: return
        val app = context.applicationContext
        val userId = getPrefs(app).getString(KEY_USER_ID, null) ?: return
        val deviceId = getPrefs(app).getString(KEY_DEVICE_ID, null) ?: return
        val maxAcc = getPrefs(app).getFloat(KEY_MAX_ACCURACY_METERS, 0f)

        val locations = result.locations ?: result.lastLocation?.let { listOf(it) }.orEmpty()
        if (locations.isEmpty()) return

        val store = SqliteLocationStore(app)
        val points = locations
            .filter { loc -> maxAcc <= 0f || !loc.hasAccuracy() || loc.accuracy <= maxAcc }
            .map { loc -> loc.toLocationPoint(userId, deviceId) }
        if (points.isEmpty()) return

        runBlocking { store.insert(points) }

        // Notify plugin so it can push to Flutter event stream and trigger flush when app is alive
        val last = points.last()
        val notify = Intent(ACTION_LOCATION_RECEIVED).apply {
            setPackage(app.packageName)
            putExtra(EXTRA_LAST_POINT_ID, last.id)
            putExtra(EXTRA_LAST_RECORDED_AT, last.recordedAtMs)
            putExtra(EXTRA_LAST_LAT, last.lat)
            putExtra(EXTRA_LAST_LNG, last.lng)
            putExtra(EXTRA_LAST_ACCURACY, last.horizontalAccuracy?.toFloat())
        }
        app.sendBroadcast(notify)
    }

    private fun Location.toLocationPoint(userId: String, deviceId: String): LocationPoint =
        LocationPoint(
            id = UUID.randomUUID().toString(),
            userId = userId,
            deviceId = deviceId,
            recordedAtMs = if (time > 0L) time else System.currentTimeMillis(),
            lat = latitude,
            lng = longitude,
            horizontalAccuracy = if (hasAccuracy()) accuracy.toDouble() else null,
            verticalAccuracy = null,
            altitude = if (hasAltitude()) altitude.toDouble() else null,
            speed = if (hasSpeed()) speed.toDouble().takeIf { it >= 0 } else null,
            course = if (hasBearing()) bearing.toDouble().takeIf { it >= 0 } else null
        )

    companion object {
        const val ACTION_LOCATION_UPDATE = "com.rtls.flutter.LOCATION_UPDATE"
        const val ACTION_LOCATION_RECEIVED = "com.rtls.flutter.LOCATION_RECEIVED"
        const val EXTRA_LAST_POINT_ID = "lastPointId"
        const val EXTRA_LAST_RECORDED_AT = "lastRecordedAtMs"
        const val EXTRA_LAST_LAT = "lastLat"
        const val EXTRA_LAST_LNG = "lastLng"
        const val EXTRA_LAST_ACCURACY = "lastAccuracy"

        const val PREFS_NAME = "rtls_flutter"
        const val KEY_USER_ID = "pending_user_id"
        const val KEY_DEVICE_ID = "pending_device_id"
        const val KEY_MAX_ACCURACY_METERS = "max_accuracy_meters"

        fun getPrefs(context: Context) =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
}
