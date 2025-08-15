package com.viridian.flutter_hce.app_layer.file_access.fields

import com.viridian.flutter_hce.app_layer.ApduField

class ApduStatusWord : ApduField {
    companion object {
        val ok = ApduStatusWord(0x90, 0x00, "SW (OK)")
        val fileNotFound = ApduStatusWord(0x6A, 0x82, "SW (File Not Found)")
        val wrongP1P2 = ApduStatusWord(0x6A, 0x86, "SW (Incorrect P1-P2)")
        val wrongOffset = ApduStatusWord(0x6B, 0x00, "SW (Wrong Offset)")
        val wrongLength = ApduStatusWord(0x67, 0x00, "SW (Wrong Length)")
        val conditionsNotSatisfied = ApduStatusWord(0x69, 0x85, "SW (Conditions Not Satisfied)")
        val insNotSupported = ApduStatusWord(0x6D, 0x00, "SW (INS Not Supported)")
        val claNotSupported = ApduStatusWord(0x6E, 0x00, "SW (CLA Not Supported)")

        /** Factory that returns a predefined instance when available, else creates a descriptive one. */
        fun fromBytes(sw1: Int, sw2: Int, name: String? = null): ApduStatusWord {
            return when {
                sw1 == 0x90 && sw2 == 0x00 -> ok
                sw1 == 0x6A && sw2 == 0x82 -> fileNotFound
                sw1 == 0x6A && sw2 == 0x86 -> wrongP1P2
                sw1 == 0x6B && sw2 == 0x00 -> wrongOffset
                sw1 == 0x67 && sw2 == 0x00 -> wrongLength
                sw1 == 0x69 && sw2 == 0x85 -> conditionsNotSatisfied
                sw1 == 0x6D && sw2 == 0x00 -> insNotSupported
                sw1 == 0x6E && sw2 == 0x00 -> claNotSupported
                else -> {
                    val hex = String.format("%02X%02X", sw1 and 0xFF, sw2 and 0xFF)
                    val effectiveName = name ?: "SW (0x$hex)"
                    ApduStatusWord(sw1, sw2, effectiveName)
                }
            }
        }
    }

    private constructor(sw1: Int, sw2: Int, name: String) : super(name, 2) {
        buffer[0] = sw1.toByte()
        buffer[1] = sw2.toByte()
    }
}
