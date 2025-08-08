package io.flutter.plugins.nfc_host_card_emulation.app_layer

sealed class HceError : Exception() {
    constructor(message: String) : super(message)
    constructor(message: String, cause: Throwable) : super(message, cause)
}

class InvalidAidError(message: String) : HceError(message)
class InvalidFileIdError(message: String) : HceError(message)
class InvalidStateError(message: String) : HceError(message)
class InvalidNdefFormatError(message: String) : HceError(message)
class FileNotFoundError(message: String) : HceError(message)
class FileAccessError(message: String) : HceError(message)
class BufferOverflowError(message: String) : HceError(message)

fun HceError.toMethodChannelError(): Pair<String, String> = when (this) {
    is InvalidAidError -> Pair("INVALID_AID", message ?: "Invalid AID")
    is InvalidFileIdError -> Pair("INVALID_FILE_ID", message ?: "Invalid file ID")
    is InvalidStateError -> Pair("INVALID_STATE", message ?: "Invalid state")
    is InvalidNdefFormatError -> Pair("INVALID_NDEF_FORMAT", message ?: "Invalid NDEF format")
    is FileNotFoundError -> Pair("FILE_NOT_FOUND", message ?: "File not found")
    is FileAccessError -> Pair("FILE_ACCESS_DENIED", message ?: "File access denied")
    is BufferOverflowError -> Pair("BUFFER_OVERFLOW", message ?: "Buffer overflow")
}
