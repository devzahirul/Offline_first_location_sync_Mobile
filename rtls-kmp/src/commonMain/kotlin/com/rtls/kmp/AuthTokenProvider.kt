package com.rtls.kmp

fun interface AuthTokenProvider {
    suspend fun accessToken(): String
}
