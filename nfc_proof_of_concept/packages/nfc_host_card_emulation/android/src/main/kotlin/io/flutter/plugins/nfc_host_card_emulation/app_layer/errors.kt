package io.flutter.plugins.nfc_host_card_emulation.app_layer

sealed class HceError(
    message: String,
    cause: Throwable? = null
) : Exception(message, cause)

class InvalidAidError(message: String) : HceError(message)
class InvalidFileIdError(message: String) : HceError(message)
class InvalidStateError(message: String) : HceError(message)
class InvalidNdefFormatError(message: String) : HceError(message)
class FileNotFoundError(message: String) : HceError(message)
class FileAccessError(message: String) : HceError(message)
class BufferOverflowError(message: String) : HceError(message)

fun HceError.toMethodChannelError(): Pair<String, String> = when (this) {
    is InvalidAidError        -> "INVALID_AID" to (message ?: "Invalid AID")
    is InvalidFileIdError     -> "INVALID_FILE_ID" to (message ?: "Invalid file ID")
    is InvalidStateError      -> "INVALID_STATE" to (message ?: "Invalid state")
    is InvalidNdefFormatError -> "INVALID_NDEF_FORMAT" to (message ?: "Invalid NDEF format")
    is FileNotFoundError      -> "FILE_NOT_FOUND" to (message ?: "File not found")
    is FileAccessError        -> "FILE_ACCESS_DENIED" to (message ?: "File access denied")
    is BufferOverflowError    -> "BUFFER_OVERFLOW" to (message ?: "Buffer overflow")
}
