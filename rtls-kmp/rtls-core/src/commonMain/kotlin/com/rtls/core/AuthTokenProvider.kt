package com.rtls.core

fun interface AuthTokenProvider {
    suspend fun accessToken(): String
}
