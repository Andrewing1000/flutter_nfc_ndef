package com.viridian.flutter_hce.app_layer.ndef_format.fields

import com.viridian.flutter_hce.app_layer.ApduData
import com.viridian.flutter_hce.app_layer.ApduField
import com.viridian.flutter_hce.app_layer.Bytes
import java.nio.charset.StandardCharsets

enum class Tnf(val value: Int) {
    EMPTY(0x00),
    WELL_KNOWN(0x01), // WKT
    MEDIA_TYPE(0x02),
    ABSOLUTE_URI(0x03),
    EXTERNAL_TYPE(0x04), // EXT
    UNKNOWN(0x05),
    UNCHANGED(0x06);

    companion object {
        fun fromValue(value: Int): Tnf {
            return values().first { it.value == value }
        }
    }
}

class NdefFlagByte private constructor(flagByte: Int) : ApduField("Flags", 1) {
    companion object {
        private const val MB_MASK = 0x80
        private const val ME_MASK = 0x40
        private const val CF_MASK = 0x20
        private const val SR_MASK = 0x10
        private const val IL_MASK = 0x08
        private const val TNF_MASK = 0x07

        fun fromByte(byte: Int): NdefFlagByte {
            return NdefFlagByte(byte)
        }

        fun record(
            tnf: Tnf,
            isShortRecord: Boolean,
            hasId: Boolean = false,
            isFirst: Boolean = true,
            isLast: Boolean = true
        ): NdefFlagByte {
            var value = tnf.value
            if (isFirst) value = value or MB_MASK
            if (isLast) value = value or ME_MASK
            if (isShortRecord) value = value or SR_MASK
            if (hasId) value = value or IL_MASK
            return NdefFlagByte(value)
        }

        fun chunk(
            tnf: Tnf? = null,
            isFirstChunk: Boolean = false,
            isLastChunk: Boolean = false,
            isFirstMessageRecord: Boolean = false,
            isLastMessageRecord: Boolean = false,
            hasId: Boolean = false
        ): NdefFlagByte {
            val value = when {
                isFirstChunk -> {
                    requireNotNull(tnf) { "TNF must be provided for the first chunk." }
                    var result = CF_MASK or tnf.value
                    if (isFirstMessageRecord) result = result or MB_MASK
                    if (hasId) result = result or IL_MASK
                    result
                }
                isLastChunk -> {
                    var result = Tnf.UNCHANGED.value
                    if (isLastMessageRecord) result = result or ME_MASK
                    result
                }
                else -> {
                    CF_MASK or Tnf.UNCHANGED.value
                }
            }
            return NdefFlagByte(value)
        }
    }

    init {
        buffer[0] = flagByte.toByte()
    }

    val isMessageBegin: Boolean
        get() = (buffer[0].toInt() and MB_MASK) != 0
    
    val isMessageEnd: Boolean
        get() = (buffer[0].toInt() and ME_MASK) != 0
    
    val isChunked: Boolean
        get() = (buffer[0].toInt() and CF_MASK) != 0
    
    val isShortRecord: Boolean
        get() = (buffer[0].toInt() and SR_MASK) != 0
    
    val hasId: Boolean
        get() = (buffer[0].toInt() and IL_MASK) != 0
    
    val tnf: Tnf
        get() {
            val tnfValue = buffer[0].toInt() and TNF_MASK
            return Tnf.fromValue(tnfValue)
        }
}

class NdefTypeLengthField(length: Int) : ApduField("Type Length", 1) {
    companion object {
        val zero = NdefTypeLengthField(0)
        val forWkt = NdefTypeLengthField(1)

        fun of(length: Int): NdefTypeLengthField = when (length) {
            0 -> zero
            1 -> forWkt
            else -> NdefTypeLengthField(length)
        }
    }

    init {
        require(length in 0..255) { "Type Length is invalid." }
        buffer[0] = length.toByte()
    }
}

abstract class NdefPayloadLengthField : ApduField {
    abstract fun getValue(): Int

    companion object {
        fun create(length: Int): NdefPayloadLengthField {
            return if (length < 256) {
                ShortNdefPayloadLengthField(length)
            } else {
                LongNdefPayloadLengthField(length)
            }
        }
    }

    protected constructor(name: String, size: Int) : super(name, size)
}

private class ShortNdefPayloadLengthField(private val payloadLength: Int) : NdefPayloadLengthField("Payload Length (SR)", 1) {
    init {
        require(payloadLength in 0..255) { "Payload Length for short record is invalid." }
        buffer[0] = payloadLength.toByte()
    }

    override fun getValue(): Int = payloadLength
}

private class LongNdefPayloadLengthField(private val payloadLength: Int) : NdefPayloadLengthField("Payload Length", 4) {
    init {
        require(payloadLength >= 0 && payloadLength <= 0xFFFFFFFF.toInt()) { "Payload Length for long record is invalid." }
        buffer[0] = ((payloadLength shr 24) and 0xFF).toByte()
        buffer[1] = ((payloadLength shr 16) and 0xFF).toByte()
        buffer[2] = ((payloadLength shr 8) and 0xFF).toByte()
        buffer[3] = (payloadLength and 0xFF).toByte()
    }

    override fun getValue(): Int = payloadLength
}

class NdefIdLengthField(length: Int) : ApduField("ID Length", 1) {
    companion object {
        val zero = NdefIdLengthField(0)
        val one = NdefIdLengthField(1)

        fun of(length: Int): NdefIdLengthField = when (length) {
            0 -> zero
            1 -> one
            else -> NdefIdLengthField(length)
        }
    }
    init {
        require(length in 0..255) { "ID Length is invalid." }
        buffer[0] = length.toByte()
    }
}

class NdefTypeField(typeBytes: Bytes, val tnf: Tnf) : ApduData(typeBytes, "Type") {
    companion object {
        fun wellKnown(type: String): NdefTypeField {
            return NdefTypeField(type.toByteArray(StandardCharsets.US_ASCII), Tnf.WELL_KNOWN)
        }

        fun mediaType(mimeType: String): NdefTypeField {
            return NdefTypeField(mimeType.toByteArray(StandardCharsets.US_ASCII), Tnf.MEDIA_TYPE)
        }

        fun externalType(externalType: String): NdefTypeField {
            return NdefTypeField(externalType.toByteArray(StandardCharsets.US_ASCII), Tnf.EXTERNAL_TYPE)
        }

        val text = wellKnown("T")
        val uri = wellKnown("U")
        val smartPoster = wellKnown("Sp")
        val textPlain = mediaType("text/plain")
        val textJson = mediaType("text/json")

        val empty = NdefTypeField(ByteArray(0), Tnf.EMPTY)
        val unknown = NdefTypeField(ByteArray(0), Tnf.UNKNOWN)
        val unchanged = NdefTypeField(ByteArray(0), Tnf.UNCHANGED)

        /** Smart factory mirroring Dart: reuse predefined instances when possible */
        fun of(typeBytes: Bytes, tnf: Tnf): NdefTypeField {
            return when (tnf) {
                Tnf.WELL_KNOWN -> {
                    // Handle common WKT types
                    val str = try { String(typeBytes, StandardCharsets.US_ASCII) } catch (_: Exception) { null }
                    when (str) {
                        "T" -> text
                        "U" -> uri
                        "Sp" -> smartPoster
                        else -> NdefTypeField(typeBytes, tnf)
                    }
                }
                Tnf.MEDIA_TYPE -> {
                    val mime = try { String(typeBytes, StandardCharsets.US_ASCII) } catch (_: Exception) { null }
                    when (mime) {
                        "text/plain" -> textPlain
                        "text/json" -> textJson
                        else -> NdefTypeField(typeBytes, tnf)
                    }
                }
                Tnf.EMPTY -> if (typeBytes.isEmpty()) empty else NdefTypeField(typeBytes, tnf)
                Tnf.UNKNOWN -> if (typeBytes.isEmpty()) unknown else NdefTypeField(typeBytes, tnf)
                Tnf.UNCHANGED -> if (typeBytes.isEmpty()) unchanged else NdefTypeField(typeBytes, tnf)
                else -> NdefTypeField(typeBytes, tnf)
            }
        }
    }
}

class NdefIdField : ApduData {
    constructor(id: Bytes) : super(id, "ID")

    companion object {
        val empty = NdefIdField(ByteArray(0))

        fun of(id: Bytes): NdefIdField {
            return if (id.isEmpty()) empty else NdefIdField(id)
        }
        fun fromAscii(id: String): NdefIdField {
            if (id.isEmpty()) return empty
            return NdefIdField(id.toByteArray(StandardCharsets.US_ASCII))
        }
    }
}

class NdefPayload(payload: Bytes) : ApduData(payload, "Payload") {
    companion object {
        val empty = NdefPayload(ByteArray(0))
        fun of(payload: Bytes): NdefPayload = if (payload.isEmpty()) empty else NdefPayload(payload)
    }
}
