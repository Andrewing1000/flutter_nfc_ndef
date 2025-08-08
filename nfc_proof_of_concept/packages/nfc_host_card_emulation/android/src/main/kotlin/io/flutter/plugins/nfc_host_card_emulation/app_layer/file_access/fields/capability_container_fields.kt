package io.flutter.plugins.nfc_host_card_emulation.file_access.fields

import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduField

class CcLenField(len: Int) : ApduField("CCLEN", 2) {
    companion object {
        val defaultLen = CcLenField(15)
    }

    init {
        require(len in 15..0xFFFF) { "Capability Container length must be >= 15." }
        buffer[0] = (len shr 8 and 0xFF).toByte()
        buffer[1] = (len and 0xFF).toByte()
    }
}

class CcMappingVersionField private constructor(version: Int) : ApduField("MappingVersion", 1) {
    companion object {
        val v2_0 = CcMappingVersionField(0x20)
    }

    init {
        buffer[0] = version.toByte()
    }
}

class CcMaxApduDataSizeField private constructor(size: Int, name: String) : ApduField(name, 2) {
    companion object {
        fun mLe(size: Int = 0x00FF) = CcMaxApduDataSizeField(size, "MLe")
        fun mLc(size: Int = 0x00FF) = CcMaxApduDataSizeField(size, "MLc")
    }

    init {
        require(size in 1..0xFFFF) { "$name size must be a positive 16-bit integer." }
        buffer[0] = (size shr 8 and 0xFF).toByte()
        buffer[1] = (size and 0xFF).toByte()
    }
}