package com.rtls.rtls_flutter

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.rtls.kmp.LocationSyncClientEvent
import com.rtls.kmp.RTLSKmp

class RtlsFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var channel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var client: com.rtls.kmp.LocationSyncClient? = null
    private var context: Context? = null
    private var lastUserId: String? = null
    private var lastDeviceId: String? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.rtls.flutter/rtls")
        channel!!.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "com.rtls.flutter/rtls_events")
        eventChannel!!.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        client?.stopTracking()
        client = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "configure" -> {
                val baseUrl = call.argument<String>("baseUrl") ?: ""
                val userId = call.argument<String>("userId") ?: ""
                val deviceId = call.argument<String>("deviceId") ?: ""
                val accessToken = call.argument<String>("accessToken") ?: ""
                val ctx = context ?: run {
                    result.error("NO_CONTEXT", "Context not available", null)
                    return
                }
                client?.stopTracking()
                lastUserId = userId
                lastDeviceId = deviceId
                client = RTLSKmp.createLocationSyncClient(ctx, baseUrl, userId, deviceId, accessToken, scope)
                result.success(null)
            }
            "startTracking" -> {
                val ctx = context ?: run {
                    result.error("NO_CONTEXT", "Context not available", null)
                    return
                }
                val c = client
                if (c == null) {
                    result.error("NOT_CONFIGURED", "Call configure first", null)
                    return
                }
                val userId = lastUserId ?: return result.error("INVALID", "Configure first", null)
                val deviceId = lastDeviceId ?: return result.error("INVALID", "Configure first", null)
                val flow = RTLSKmp.createLocationFlow(ctx, userId, deviceId)
                c.startCollectingLocation(flow)
                result.success(null)
            }
            "stopTracking" -> {
                client?.stopTracking()
                result.success(null)
            }
            "requestAlwaysAuthorization" -> result.success(null)
            "getStats" -> {
                scope.launch {
                    val stats = try {
                        client?.stats()
                    } catch (e: Exception) {
                        null
                    }
                    withContext(Dispatchers.Main) {
                        if (stats != null) {
                            result.success(mapOf(
                                "pendingCount" to stats.pendingCount,
                                "oldestPendingRecordedAtMs" to (stats.oldestPendingRecordedAtMs ?: 0)
                            ))
                        } else {
                            result.success(mapOf("pendingCount" to -1, "oldestPendingRecordedAtMs" to null))
                        }
                    }
                }
            }
            "flushNow" -> {
                scope.launch {
                    try {
                        client?.flushNow()
                        withContext(Dispatchers.Main) { result.success(null) }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) { result.error("FLUSH_FAILED", e.message, null) }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        scope.launch {
            client?.events?.collectLatest { event ->
                val map = when (event) {
                    is LocationSyncClientEvent.Recorded -> mapOf(
                        "type" to "recorded",
                        "point" to mapOf(
                            "id" to event.point.id,
                            "userId" to event.point.userId,
                            "deviceId" to event.point.deviceId,
                            "recordedAtMs" to event.point.recordedAtMs,
                            "lat" to event.point.lat,
                            "lng" to event.point.lng
                        )
                    )
                    is LocationSyncClientEvent.SyncEvent -> mapOf(
                        "type" to "syncEvent",
                        "event" to when (val e = event.event) {
                            is com.rtls.kmp.SyncEngineEvent.UploadSuccess -> "uploadSucceeded"
                            is com.rtls.kmp.SyncEngineEvent.UploadFailed -> "uploadFailed"
                            else -> "unknown"
                        }
                    )
                    is LocationSyncClientEvent.Error -> mapOf("type" to "error", "message" to event.message)
                    LocationSyncClientEvent.TrackingStarted -> mapOf("type" to "trackingStarted")
                    LocationSyncClientEvent.TrackingStopped -> mapOf("type" to "trackingStopped")
                }
                kotlinx.coroutines.withContext(Dispatchers.Main) { eventSink?.success(map) }
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
