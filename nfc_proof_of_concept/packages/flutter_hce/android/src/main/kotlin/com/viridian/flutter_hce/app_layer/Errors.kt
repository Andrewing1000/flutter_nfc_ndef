package com.viridian.flutter_hce.app_layer

class HceException(
    val code: HceErrorCode,
    override val message: String,
    val details: String? = null
) : Exception(message) {
    
    override fun toString(): String {
        return if (details != null) {
            "HceException: [$code] $message\nDetails: $details"
        } else {
            "HceException: [$code] $message"
        }
    }
}

enum class HceErrorCode {
    // Initialization Errors
    INVALID_AID,
    SERVICE_NOT_AVAILABLE,

    // State Machine Errors
    INVALID_STATE,
    INVALID_TRANSITION,
    POWER_LOSS,
    BUFFER_OVERFLOW,

    // NDEF Errors
    INVALID_NDEF_FORMAT,
    MESSAGE_TOO_LARGE,
    INVALID_CHUNK_SEQUENCE,

    // File System Errors
    FILE_NOT_FOUND,
    INVALID_FILE_ID,
    FILE_ACCESS_DENIED,

    // Communication Errors
    CONNECTION_LOST,
    RESPONSE_TIMEOUT,

    // Resource Errors
    OUT_OF_MEMORY,

    // Unknown Errors
    UNKNOWN
}
