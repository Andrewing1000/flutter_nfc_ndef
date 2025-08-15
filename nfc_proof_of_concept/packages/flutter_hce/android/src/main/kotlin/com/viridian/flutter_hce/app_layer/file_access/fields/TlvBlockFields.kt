package com.viridian.flutter_hce.app_layer.file_access.fields

import com.viridian.flutter_hce.app_layer.ApduField

class TlvTag private constructor(tag: Int, name: String) : ApduField(name, 1) {
    companion object {
        val ndef = TlvTag(0x04, "Tag (NDEF)")
        val proprietary = TlvTag(0x05, "Tag (Proprietary)")

        /** Factory to reuse predefined instances or create a new one with a descriptive name */
        fun fromByte(tag: Int, name: String? = null): TlvTag = when (tag) {
            0x04 -> ndef
            0x05 -> proprietary
            else -> {
                val hex = String.format("%02X", tag and 0xFF)
                val effectiveName = name ?: "Tag (0x$hex)"
                TlvTag(tag, effectiveName)
            }
        }
    }

    init {
        buffer[0] = tag.toByte()
    }
}

class TlvLength private constructor(len: Int) : ApduField("Length", 1) {
    companion object {
        val forFileControl = TlvLength(0x06)
    }

    init {
        buffer[0] = len.toByte()
    }
}

class FileIdField(fileId: Int) : ApduField("File ID", 2) {
    companion object {
        val forNdef = FileIdField(0xE104)
    }

    init {
        require(fileId in 0..0xFFFF) { "File ID must be a 16-bit unsigned integer." }
        buffer[0] = ((fileId shr 8) and 0xFF).toByte()
        buffer[1] = (fileId and 0xFF).toByte()
    }
}

class MaxFileSizeField(size: Int) : ApduField("Max File Size", 2) {
    init {
        require(size >= 11 && size <= 0xFFFF) { "Max File Size is invalid. Must be >= 11 bytes." }
        buffer[0] = ((size shr 8) and 0xFF).toByte()
        buffer[1] = (size and 0xFF).toByte()
    }
}

class ReadAccessField private constructor(access: Int, name: String) : ApduField(name, 1) {
    companion object {
        val granted = ReadAccessField(0x00, "Read Access (Granted)")

        /** Factory to reuse predefined instance or create a new one with descriptive name */
        fun fromByte(accessByte: Int, name: String? = null): ReadAccessField {
            return if ((accessByte and 0xFF) == 0x00) {
                granted
            } else {
                val hex = String.format("%02X", accessByte and 0xFF)
                val effectiveName = name ?: "Read Access (0x$hex)"
                ReadAccessField(accessByte, effectiveName)
            }
        }
    }

    init {
        buffer[0] = access.toByte()
    }
}

class WriteAccessField private constructor(access: Int, name: String) : ApduField(name, 1) {
    companion object {
        val granted = WriteAccessField(0x00, "Write Access (Granted)")
        val denied = WriteAccessField(0xFF, "Write Access (Denied)")

        /** Factory from boolean (writable? granted:denied) */
        fun fromWritable(isWritable: Boolean): WriteAccessField = if (isWritable) granted else denied

        /** Factory from raw byte value */
        fun fromByte(accessByte: Int, name: String? = null): WriteAccessField {
            return when (accessByte and 0xFF) {
                0x00 -> granted
                0xFF -> denied
                else -> {
                    val hex = String.format("%02X", accessByte and 0xFF)
                    val effectiveName = name ?: "Write Access (0x$hex)"
                    WriteAccessField(accessByte, effectiveName)
                }
            }
        }
    }

    init {
        buffer[0] = access.toByte()
    }
}
