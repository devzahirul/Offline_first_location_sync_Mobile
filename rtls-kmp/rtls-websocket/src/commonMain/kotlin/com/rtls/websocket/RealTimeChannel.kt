package com.rtls.websocket

import kotlinx.coroutines.flow.Flow

/**
 * Low-level WebSocket channel abstraction. Platform-specific implementations
 * handle the actual connection (OkHttp on Android, URLSession on iOS).
 */
interface RealTimeChannel {
    val isConnected: Boolean
    val incomingMessages: Flow<String>
    suspend fun connect(url: String, headers: Map<String, String>)
    suspend fun send(message: String)
    suspend fun disconnect(code: Int = 1000, reason: String = "")
}
