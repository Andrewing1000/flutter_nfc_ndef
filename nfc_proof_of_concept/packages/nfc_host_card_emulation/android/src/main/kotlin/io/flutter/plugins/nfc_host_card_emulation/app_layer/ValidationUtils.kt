package io.flutter.plugins.nfc_host_card_emulation.app_layer

object ValidationUtils {
    fun validateAid(aid: ByteArray) {
        if (aid.size !in 5..16) {
            throw InvalidAidError("AID length must be between 5 and 16 bytes")
        }
    }

    fun validateFileId(fileId: Int) {
        if (fileId < 0x0001 || fileId > 0xE102) {
            throw InvalidFileIdError("File ID must be between 0x0001 and 0xE102")
        }
    }

    fun validateNdefMessageSize(maxSize: Int) {
        if (maxSize < 16 || maxSize > 32767) {
            throw InvalidNdefFormatError("NDEF message size must be between 16 and 32767 bytes")
        }
    }

    fun validateRecordTypes(recordsList: List<Map<String, Any>>) {
        if (recordsList.isEmpty()) {
            throw InvalidNdefFormatError("At least one NDEF record is required")
        }

        recordsList.forEach { record ->
            val type = record["type"] as? String
                ?: throw InvalidNdefFormatError("Record type must be a string")
            val payload = record["payload"] as? ByteArray
                ?: throw InvalidNdefFormatError("Record payload must be a byte array")

            if (type.isEmpty()) {
                throw InvalidNdefFormatError("Record type cannot be empty")
            }
            if (payload.isEmpty()) {
                throw InvalidNdefFormatError("Record payload cannot be empty")
            }
        }
    }
}
