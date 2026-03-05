package com.rtls.websocket

import com.rtls.core.AuthTokenProvider

data class WebSocketConfig(
    val baseUrl: String,
    val tokenProvider: AuthTokenProvider,
    val autoReconnect: Boolean = true,
    val reconnectBaseDelayMs: Long = 1_000L,
    val reconnectMaxDelayMs: Long = 30_000L,
    val pingIntervalMs: Long = 30_000L
)
