package com.rtls.location

import com.rtls.core.LocationPoint
import kotlinx.coroutines.flow.Flow

/**
 * Abstract location source. Platform implementations provide GPS data
 * as a Flow of LocationPoint. Usable independently without sync or WebSocket.
 */
interface LocationSource {
    fun locationFlow(userId: String, deviceId: String): Flow<LocationPoint>
}
