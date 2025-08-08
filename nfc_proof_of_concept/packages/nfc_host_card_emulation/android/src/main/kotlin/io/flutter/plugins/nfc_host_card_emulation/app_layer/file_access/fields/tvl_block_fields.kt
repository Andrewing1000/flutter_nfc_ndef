package io.flutter.plugins.nfc_host_card_emulation.file_access.fields

import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduField

class TlvTag private constructor(tag: Int, name: String) : ApduField(name, 1) {
    companion object {
        val ndef = TlvTag(0x04, "Tag (NDEF)")
        val proprietary = TlvTag(0x05, "Tag (Proprietary)")
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
        buffer[0] = (fileId shr 8 and 0xFF).toByte()
        buffer[1] = (fileId and 0xFF).toByte()
    }
}

class MaxFileSizeField(size: Int) : ApduField("Max File Size", 2) {
    init {
        require(size in 11..0xFFFF) { "Max File Size is invalid. Must be >= 11 bytes." }
        buffer[0] = (size shr 8 and 0xFF).toByte()
        buffer[1] = (size and 0xFF).toByte()
    }
}

class ReadAccessField private constructor(access: Int) : ApduField("Read Access", 1) {
    companion object {
        val granted = ReadAccessField(0x00)
    }

    init {
        buffer[0] = access.toByte()
    }
}

class WriteAccessField(isWritable: Boolean) : ApduField("Write Access", 1) {
    companion object {
        val granted = WriteAccessField(true)
        val denied = WriteAccessField(false)
    }

    init {
        buffer[0] = if (isWritable) 0x00.toByte() else 0xFF.toByte()
    }
}