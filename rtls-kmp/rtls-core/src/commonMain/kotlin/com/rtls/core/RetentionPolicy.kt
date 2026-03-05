package com.rtls.core

data class RetentionPolicy(
    val sentPointsMaxAgeMs: Long? = null
) {
    companion object {
        val KeepForever = RetentionPolicy(sentPointsMaxAgeMs = null)
        val Recommended = RetentionPolicy(sentPointsMaxAgeMs = 7L * 24 * 60 * 60 * 1000)
    }
}
