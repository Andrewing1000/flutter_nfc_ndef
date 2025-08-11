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

        fun fromBytes(sw1: Int, sw2: Int): ApduStatusWord {
            return ApduStatusWord(sw1, sw2, "SW Deserialized")
        }
    }

    private constructor(sw1: Int, sw2: Int, name: String) : super(name, 2) {
        buffer[0] = sw1.toByte()
        buffer[1] = sw2.toByte()
    }
}
