package com.viridian.flutter_hce.app_layer.file_access.fields

import com.viridian.flutter_hce.app_layer.ApduField

class CcLenField(len: Int) : ApduField("CCLEN", 2) {
    companion object {
        val defaultLen = CcLenField(15)
    }

    init {
        require(len >= 15 && len <= 0xFFFF) { "Capability Container length must be >= 15." }
        buffer[0] = ((len shr 8) and 0xFF).toByte()
        buffer[1] = (len and 0xFF).toByte()
    }
}

class CcMappingVersionField private constructor(version: Int, name: String) : ApduField(name, 1) {
    companion object {
        /** Predefined instance for version 2.0 (0x20) with descriptive name */
        val v2_0: CcMappingVersionField = CcMappingVersionField(0x20, "MappingVersion (2.0)")

        /**
         * Factory that returns a predefined instance when available, otherwise creates a new one
         * with a descriptive name like "MappingVersion (major.minor)" unless a custom name is provided.
         */
        fun fromByte(version: Int, name: String? = null): CcMappingVersionField {
            if (version == 0x20) return v2_0
            val major = (version ushr 4) and 0x0F
            val minor = version and 0x0F
            val effectiveName = name ?: "MappingVersion ($major.$minor)"
            return CcMappingVersionField(version, effectiveName)
        }
    }

    init {
        buffer[0] = version.toByte()
    }
}

class CcMaxApduDataSizeField : ApduField {
    companion object {
        val defaultMLe = CcMaxApduDataSizeField(0x00FF, "MLe")
        val defaultMLc = CcMaxApduDataSizeField(0x00FF, "MLc")
        
        fun mLe(size: Int): CcMaxApduDataSizeField = CcMaxApduDataSizeField(size, "MLe")
        fun mLc(size: Int): CcMaxApduDataSizeField = CcMaxApduDataSizeField(size, "MLc")
    }

    private constructor(size: Int, name: String) : super(name, 2) {
        require(size > 0 && size <= 0xFFFF) { "$name size must be a positive 16-bit integer." }
        buffer[0] = ((size shr 8) and 0xFF).toByte()
        buffer[1] = (size and 0xFF).toByte()
    }
}
