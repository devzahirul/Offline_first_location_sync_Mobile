package com.rtls.websocket

import com.rtls.core.LocationPoint
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
sealed class WsClientMessage {
    abstract val type: String
}

@Serializable
@SerialName("auth")
data class WsAuthMessage(
    override val type: String = "auth",
    val token: String
) : WsClientMessage()

@Serializable
@SerialName("location.push")
data class WsLocationPush(
    override val type: String = "location.push",
    val reqId: String,
    val point: LocationPoint
) : WsClientMessage()

@Serializable
@SerialName("location.batch")
data class WsLocationBatch(
    override val type: String = "location.batch",
    val reqId: String,
    val points: List<LocationPoint>
) : WsClientMessage()

@Serializable
@SerialName("subscribe")
data class WsSubscribe(
    override val type: String = "subscribe",
    val userId: String
) : WsClientMessage()

@Serializable
@SerialName("unsubscribe")
data class WsUnsubscribe(
    override val type: String = "unsubscribe",
    val userId: String
) : WsClientMessage()

@Serializable
@SerialName("ping")
data class WsPing(override val type: String = "ping") : WsClientMessage()

// Server -> Client messages

@Serializable
data class WsServerMessage(
    val type: String,
    val reqId: String? = null,
    val status: String? = null,
    val acceptedIds: List<String>? = null,
    val rejected: List<WsRejected>? = null,
    val point: LocationPoint? = null,
    val points: List<LocationPoint>? = null,
    val cursor: String? = null,
    val userId: String? = null,
    val message: String? = null
)

@Serializable
data class WsRejected(
    val id: String,
    val reason: String
)
