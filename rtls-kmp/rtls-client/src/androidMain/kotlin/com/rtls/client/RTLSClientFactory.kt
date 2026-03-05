package com.rtls.client

import android.content.Context
import com.rtls.core.*
import com.rtls.location.*
import com.rtls.sync.*
import com.rtls.websocket.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow

/**
 * Android factory for building RTLSClient with any combination of capabilities.
 */
class RTLSClientFactory(private val context: Context) {

    class Builder(private val context: Context) {
        private var baseUrl: String = ""
        private var userId: String = ""
        private var deviceId: String = ""
        private var accessToken: String = ""
        private var scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

        private var enableOfflineSync: Boolean = false
        private var batchingPolicy: BatchingPolicy = BatchingPolicy()
        private var retryPolicy: SyncRetryPolicy = SyncRetryPolicy.Default
        private var retentionPolicy: RetentionPolicy = RetentionPolicy.Recommended
        private var pullAPI: LocationPullAPI? = null
        private var mergeStrategy: LocationMergeStrategy? = null

        private var enableWebSocket: Boolean = false
        private var wsAutoReconnect: Boolean = true

        private var enableLocation: Boolean = false
        private var locationParams: LocationRequestParams = LocationRequestParams()
        private var recordingDecider: LocationRecordingDecider? = null

        fun baseUrl(url: String) = apply { this.baseUrl = url }
        fun userId(id: String) = apply { this.userId = id }
        fun deviceId(id: String) = apply { this.deviceId = id }
        fun accessToken(token: String) = apply { this.accessToken = token }
        fun scope(scope: CoroutineScope) = apply { this.scope = scope }

        fun offlineSync(
            batchingPolicy: BatchingPolicy = BatchingPolicy(),
            retryPolicy: SyncRetryPolicy = SyncRetryPolicy.Default,
            retentionPolicy: RetentionPolicy = RetentionPolicy.Recommended,
            pullAPI: LocationPullAPI? = null,
            mergeStrategy: LocationMergeStrategy? = null
        ) = apply {
            this.enableOfflineSync = true
            this.batchingPolicy = batchingPolicy
            this.retryPolicy = retryPolicy
            this.retentionPolicy = retentionPolicy
            this.pullAPI = pullAPI
            this.mergeStrategy = mergeStrategy
        }

        fun webSocket(autoReconnect: Boolean = true) = apply {
            this.enableWebSocket = true
            this.wsAutoReconnect = autoReconnect
        }

        fun location(
            params: LocationRequestParams = LocationRequestParams(),
            recordingDecider: LocationRecordingDecider? = null
        ) = apply {
            this.enableLocation = true
            this.locationParams = params
            this.recordingDecider = recordingDecider
        }

        fun build(): RTLSClient {
            require(baseUrl.isNotBlank()) { "baseUrl is required" }
            require(userId.isNotBlank()) { "userId is required" }
            require(deviceId.isNotBlank()) { "deviceId is required" }

            val tokenProvider = AuthTokenProvider { accessToken }
            val networkMonitor = AndroidNetworkMonitor(context)

            val store: LocationStore? = if (enableOfflineSync) SqliteLocationStore(context) else null
            val api: LocationSyncAPI? = if (enableOfflineSync) OkHttpLocationSyncAPI(baseUrl, tokenProvider) else null
            val syncEngine: SyncEngine? = if (enableOfflineSync && store != null && api != null) {
                SyncEngine(
                    store = store, api = api, batching = batchingPolicy,
                    retryPolicy = retryPolicy, retentionPolicy = retentionPolicy,
                    networkMonitor = networkMonitor, scope = scope,
                    pullAPI = pullAPI, mergeStrategy = mergeStrategy
                )
            } else null

            val wsClient: RealTimeLocationClient? = if (enableWebSocket) {
                RealTimeLocationClient(
                    config = WebSocketConfig(
                        baseUrl = baseUrl, tokenProvider = tokenProvider,
                        autoReconnect = wsAutoReconnect
                    ),
                    channel = OkHttpRealTimeChannel(),
                    scope = scope
                )
            } else null

            return RTLSClient(
                store = store, syncEngine = syncEngine, webSocketClient = wsClient,
                userId = userId, deviceId = deviceId, scope = scope,
                recordingDecider = recordingDecider
            )
        }

        fun buildLocationFlow(): Flow<LocationPoint> {
            val provider = AndroidLocationProvider(context)
            return provider.locationFlow(userId, deviceId, locationParams)
        }
    }
}
