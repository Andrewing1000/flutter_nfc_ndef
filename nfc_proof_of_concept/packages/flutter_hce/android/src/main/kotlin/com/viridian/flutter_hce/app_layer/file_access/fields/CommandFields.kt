package com.viridian.flutter_hce.app_layer.file_access.fields

import com.viridian.flutter_hce.app_layer.ApduField

class ApduClass private constructor(claByte: Int) : ApduField("CLA", 1) {
    companion object {
        val standard = ApduClass(0x00)
    }

    init {
        buffer[0] = claByte.toByte()
    }
}

class ApduInstruction : ApduField {
    companion object {
        const val SELECT_BYTE = 0xA4
        const val READ_BINARY_BYTE = 0xB0
        const val UPDATE_BINARY_BYTE = 0xD6

        val select = ApduInstruction(SELECT_BYTE, "INS (SELECT)")
        val readBinary = ApduInstruction(READ_BINARY_BYTE, "INS (READ_BINARY)")
        val updateBinary = ApduInstruction(UPDATE_BINARY_BYTE, "INS (UPDATE_BINARY)")

        /** Factory to reuse predefined instances or create a new one with a descriptive name */
        fun fromByte(insByte: Int, name: String? = null): ApduInstruction {
            return when (insByte) {
                SELECT_BYTE -> select
                READ_BINARY_BYTE -> readBinary
                UPDATE_BINARY_BYTE -> updateBinary
                else -> {
                    val hex = String.format("%02X", insByte and 0xFF)
                    val effectiveName = name ?: "INS (0x$hex)"
                    ApduInstruction(insByte, effectiveName)
                }
            }
        }
    }

    private constructor(insByte: Int, name: String) : super(name, 1) {
        buffer[0] = insByte.toByte()
    }
}

class ApduParams(p1: Int, p2: Int, name: String) : ApduField(name, 2) {
    companion object {
        val byName = ApduParams(0x04, 0x00, "P1-P2 (ByName)")
        val byFileId = ApduParams(0x00, 0x0C, "P1-P2 (ByFileID)")

        /** Factory to return predefined instances when matching, else a named one */
        fun of(p1: Int, p2: Int, name: String? = null): ApduParams {
            return when {
                p1 == 0x04 && p2 == 0x00 -> byName
                p1 == 0x00 && p2 == 0x0C -> byFileId
                else -> {
                    val p1Hex = String.format("%02X", p1 and 0xFF)
                    val p2Hex = String.format("%02X", p2 and 0xFF)
                    val effectiveName = name ?: "P1-P2 (0x$p1Hex, 0x$p2Hex)"
                    ApduParams(p1, p2, effectiveName)
                }
            }
        }

        fun forOffset(offset: Int): ApduParams {
            require(offset in 0..0xFFFF) { "Offset must be a 16-bit unsigned integer (0-65535)." }
            val p1 = (offset shr 8) and 0xFF
            val p2 = offset and 0xFF
            return ApduParams(p1, p2, "P1-P2 (Offset)")
        }
    }

    init {
        buffer[0] = p1.toByte()
        buffer[1] = p2.toByte()
    }
}

class ApduLc(lc: Int) : ApduField("Lc", 1) {
    init {
        require(lc in 0..255) { "Lc must be an 8-bit unsigned integer (0-255)." }
        buffer[0] = lc.toByte()
    }
}

class ApduLe(le: Int) : ApduField("Le", 1) {
    init {
        require(le in 0..255) { "Le must be an 8-bit unsigned integer (0-255). Use 0 for 256 bytes." }
        buffer[0] = le.toByte()
    }
}
