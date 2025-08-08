package io.flutter.plugins.nfc_host_card_emulation.ndef_format.fields

import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduData
import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduField
import io.flutter.plugins.nfc_host_card_emulation.app_layer.Bytes
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets

enum class Tnf(val value: Int) {
    EMPTY(0x00),
    WELL_KNOWN(0x01),
    MEDIA_TYPE(0x02),
    ABSOLUTE_URI(0x03),
    EXTERNAL_TYPE(0x04),
    UNKNOWN(0x05),
    UNCHANGED(0x06);

    companion object {
        fun fromValue(value: Int) = values().firstOrNull { it.value == value } ?: UNKNOWN
    }
}

class NdefFlagByte private constructor(flagByte: Int) : ApduField("Flags", 1) {
    val isMessageBegin: Boolean get() = (buffer[0].toInt() and MB_MASK) != 0
    val isMessageEnd: Boolean get() = (buffer[0].toInt() and ME_MASK) != 0
    val isChunked: Boolean get() = (buffer[0].toInt() and CF_MASK) != 0
    val isShortRecord: Boolean get() = (buffer[0].toInt() and SR_MASK) != 0
    val hasId: Boolean get() = (buffer[0].toInt() and IL_MASK) != 0
    val tnf: Tnf get() = Tnf.fromValue(buffer[0].toInt() and TNF_MASK)

    init {
        buffer[0] = flagByte.toByte()
    }

    companion object {
        private const val MB_MASK = 0x80
        private const val ME_MASK = 0x40
        private const val CF_MASK = 0x20
        private const val SR_MASK = 0x10
        private const val IL_MASK = 0x08
        private const val TNF_MASK = 0x07

        fun fromByte(byte: Byte) = NdefFlagByte(byte.toInt() and 0xFF)

        fun record(
            tnf: Tnf, isShortRecord: Boolean, hasId: Boolean = false,
            isFirst: Boolean = true, isLast: Boolean = true
        ): NdefFlagByte {
            var value = tnf.value
            if (isFirst) value = value or MB_MASK
            if (isLast) value = value or ME_MASK
            if (isShortRecord) value = value or SR_MASK
            if (hasId) value = value or IL_MASK
            return NdefFlagByte(value)
        }
    }
}

class NdefTypeLengthField(length: Int) : ApduField("Type Length", 1) {
    companion object {
        val zero = NdefTypeLengthField(0)
    }

    init {
        require(length in 0..255) { "Type Length is invalid." }
        buffer[0] = length.toByte()
    }
}

sealed class NdefPayloadLengthField(size: Int, name: String) : ApduField(name, size) {
    abstract fun getValue(): Long

    companion object {
        fun fromBytes(isShortRecord: Boolean, data: Bytes, offset: Int): Pair<NdefPayloadLengthField, Int> {
            return if (isShortRecord) {
                require(offset < data.size) { "Malformed NDEF: Not enough bytes for short payload length" }
                val length = data[offset].toInt() and 0xFF
                Pair(Short(length), 1)
            } else {
                require(offset + 3 < data.size) { "Malformed NDEF: Not enough bytes for long payload length" }
                val length = ByteBuffer.wrap(data, offset, 4).int.toLong()
                Pair(Long(length), 4)
            }
        }

        fun of(length: Long): NdefPayloadLengthField {
            return if (length < 256) Short(length.toInt()) else Long(length)
        }
    }

    class Short(private val length: Int) : NdefPayloadLengthField(1, "Payload Length (SR)") {
        init {
            require(length in 0..255)
            buffer[0] = length.toByte()
        }
        override fun getValue(): Long = length.toLong()
    }

    class Long(private val length: Long) : NdefPayloadLengthField(4, "Payload Length") {
        init {
            require(length in 0..0xFFFFFFFF)
            buffer[0] = (length shr 24 and 0xFF).toByte()
            buffer[1] = (length shr 16 and 0xFF).toByte()
            buffer[2] = (length shr 8 and 0xFF).toByte()
            buffer[3] = (length and 0xFF).toByte()
        }
        override fun getValue(): Long = length
    }
}

class NdefIdLengthField(length: Int) : ApduField("ID Length", 1) {
    init {
        require(length in 0..255) { "ID Length is invalid." }
        buffer[0] = length.toByte()
    }
}

class NdefTypeField private constructor(typeBytes: Bytes, val tnf: Tnf) : ApduData("Type", typeBytes) {
    companion object {
        fun wellKnown(type: String) = NdefTypeField(type.toByteArray(StandardCharsets.US_ASCII), Tnf.WELL_KNOWN)
    }
}

class NdefIdField(id: Bytes) : ApduData("ID", id) {
    companion object {
        fun fromAscii(id: String) = NdefIdField(id.toByteArray(StandardCharsets.US_ASCII))
    }
}

class NdefPayload(payload: Bytes) : ApduData("Payload", payload)