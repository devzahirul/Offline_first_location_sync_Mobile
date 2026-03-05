package com.rtls.core

import kotlinx.coroutines.flow.Flow

interface NetworkMonitor {
    suspend fun isOnline(): Boolean
    val onlineFlow: Flow<Boolean>?
        get() = null
}
