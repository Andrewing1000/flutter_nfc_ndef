package io.flutter.plugins.nfc_host_card_emulation.file_access.fields

import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduField

class ApduStatusWord private constructor(sw1: Int, sw2: Int, name: String) : ApduField(name, 2) {
    companion object {
        val ok = ApduStatusWord(0x90, 0x00, "SW (OK)")
        val fileNotFound = ApduStatusWord(0x6A, 0x82, "SW (File Not Found)")
        val wrongP1P2 = ApduStatusWord(0x6A, 0x86, "SW (Incorrect P1-P2)")
        val wrongOffset = ApduStatusWord(0x6B, 0x00, "SW (Wrong Offset)")
        val wrongLength = ApduStatusWord(0x67, 0x00, "SW (Wrong Length)")
        val conditionsNotSatisfied = ApduStatusWord(0x69, 0x85, "SW (Conditions Not Satisfied)")
        val insNotSupported = ApduStatusWord(0x6D, 0x00, "SW (INS Not Supported)")
        val claNotSupported = ApduStatusWord(0x6E, 0x00, "SW (CLA Not Supported)")
    }

    init {
        buffer[0] = sw1.toByte()
        buffer[1] = sw2.toByte()
    }
}