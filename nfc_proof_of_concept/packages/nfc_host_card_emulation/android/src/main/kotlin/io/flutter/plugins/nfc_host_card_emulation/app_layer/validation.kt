package io.flutter.plugins.nfc_host_card_emulation.app_layer

object ValidationUtils {
    fun validateAid(aid: ByteArray) {
        if (aid.size < 5 || aid.size > 16) {
            throw InvalidAidError("AID length must be between 5 and 16 bytes.")
        }
        if (aid[0] == 0x00.toByte() || aid[0] == 0xFF.toByte()) {
            throw InvalidAidError("Invalid RID: first byte cannot be 0x00 or 0xFF")
        }
    }

    fun validateFileId(fileId: Int) {
        if (fileId < 0x0000 || fileId > 0xFFFF) {
            throw InvalidFileIdError("File ID must be between 0x0000 and 0xFFFF")
        }
        if (fileId == 0x3F00 || fileId == 0x3FFF) {
            throw InvalidFileIdError("Invalid file ID: 0x3F00 and 0x3FFF are reserved")
        }
    }

    fun validateNdefMessageSize(size: Int) {
        if (size > 0xFFFE) {
            throw BufferOverflowError("NDEF message size cannot exceed 65534 bytes")
        }
    }

    fun validateOffset(offset: Int, maxSize: Int) {
        if (offset < 0 || offset > maxSize) {
            throw InvalidStateError("Invalid offset: $offset")
        }
    }

    fun validateRecordTypes(records: List<Map<String, Any>>) {
        for (record in records) {
            val type = record["type"] as? String
                ?: throw InvalidNdefFormatError("Missing type in NDEF record")
            val payload = record["payload"] as? ByteArray
                ?: throw InvalidNdefFormatError("Missing payload in NDEF record")
            if (type.isEmpty()) {
                throw InvalidNdefFormatError("NDEF record type cannot be empty")
            }
            if (payload.size > 0xFFFF) {
                throw InvalidNdefFormatError("NDEF record payload too large")
            }
        }
    }
}
