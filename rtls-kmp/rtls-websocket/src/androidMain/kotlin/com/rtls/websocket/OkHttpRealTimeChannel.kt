package com.rtls.websocket

import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import okhttp3.*
import java.util.concurrent.TimeUnit

class OkHttpRealTimeChannel(
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.SECONDS)
        .connectionSpecs(listOf(ConnectionSpec.CLEARTEXT, ConnectionSpec.MODERN_TLS, ConnectionSpec.COMPATIBLE_TLS))
        .build()
) : RealTimeChannel {

    private var webSocket: WebSocket? = null
    @Volatile
    override var isConnected: Boolean = false
        private set

    private val _incoming = MutableSharedFlow<String>(extraBufferCapacity = 256)
    override val incomingMessages: Flow<String> = _incoming.asSharedFlow()

    override suspend fun connect(url: String, headers: Map<String, String>) {
        val requestBuilder = Request.Builder().url(url)
        headers.forEach { (k, v) -> requestBuilder.addHeader(k, v) }
        val request = requestBuilder.build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                isConnected = true
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                _incoming.tryEmit(text)
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                isConnected = false
                webSocket.close(code, reason)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                isConnected = false
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                isConnected = false
                _incoming.tryEmit("{\"type\":\"error\",\"message\":\"${t.message}\"}")
            }
        })
    }

    override suspend fun send(message: String) {
        webSocket?.send(message) ?: throw IllegalStateException("WebSocket not connected")
    }

    override suspend fun disconnect(code: Int, reason: String) {
        webSocket?.close(code, reason)
        webSocket = null
        isConnected = false
    }
}
