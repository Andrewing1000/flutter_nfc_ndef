package com.viridian.flutter_hce.app_layer.ndef_format.serializers

import com.viridian.flutter_hce.app_layer.ApduSerializer
import com.viridian.flutter_hce.app_layer.Bytes
import com.viridian.flutter_hce.app_layer.ndef_format.fields.*
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.StandardCharsets
import org.json.JSONObject

class NdefRecordSerializer private constructor(
    val flags: NdefFlagByte,
    val type: NdefTypeField,
    val payload: NdefPayload?,
    val id: NdefIdField?
) : ApduSerializer("NDEF Record") {

    private val typeLength: NdefTypeLengthField = NdefTypeLengthField(type.length)
    private val payloadLength: NdefPayloadLengthField = NdefPayloadLengthField.create(payload?.length ?: 0)
    private val idLength: NdefIdLengthField? = if (id != null) NdefIdLengthField(id.length) else null

    init {
        // Register fields in order, using nulls where appropriate
        register(flags)
        register(typeLength)
        register(payloadLength)
        register(if (flags.hasId) idLength else null)
        register(if (type.length > 0) type else null)
        register(if (flags.hasId) id else null)
        register(if ((payload?.length ?: 0) > 0) payload else null)
    }

    companion object {
        fun record(
            type: NdefTypeField,
            payload: NdefPayload? = null,
            id: NdefIdField? = null,
            isFirstInMessage: Boolean = true,
            isLastInMessage: Boolean = true
        ): NdefRecordSerializer {
            validateRecordArgs(type, payload, id)

            val payloadLen = payload?.length ?: 0
            val isShortRecord = payloadLen < 256
            val hasId = id != null

            val flags = NdefFlagByte.record(
                tnf = type.tnf,
                isShortRecord = isShortRecord,
                hasId = hasId,
                isFirst = isFirstInMessage,
                isLast = isLastInMessage
            )

            return NdefRecordSerializer(flags, type, payload, id)
        }

        /** Factory for WKT Text records */
        fun text(
            text: String,
            language: String,
            id: NdefIdField? = null,
            isFirstInMessage: Boolean = true,
            isLastInMessage: Boolean = true
        ): NdefRecordSerializer {
            val languageBytes = language.toByteArray(StandardCharsets.UTF_8)
            val textBytes = text.toByteArray(StandardCharsets.UTF_8)
            val flagsByte = languageBytes.size and 0x3F // lower 6 bits for lang length
            val payloadData = ByteArray(1 + languageBytes.size + textBytes.size)
            payloadData[0] = flagsByte.toByte()
            System.arraycopy(languageBytes, 0, payloadData, 1, languageBytes.size)
            System.arraycopy(textBytes, 0, payloadData, 1 + languageBytes.size, textBytes.size)
            val payload = NdefPayload(payloadData)
            return record(
                type = NdefTypeField.text,
                payload = payload,
                id = id,
                isFirstInMessage = isFirstInMessage,
                isLastInMessage = isLastInMessage
            )
        }

    /** Factory for WKT URI records */
        fun uri(
            uri: String,
            id: NdefIdField? = null,
            isFirstInMessage: Boolean = true,
            isLastInMessage: Boolean = true
        ): NdefRecordSerializer {
            val identifierCode = getUriIdentifierCode(uri)
            val uriField = getUriField(uri, identifierCode)
            val uriFieldBytes = uriField.toByteArray(StandardCharsets.UTF_8)
            val payloadData = ByteArray(1 + uriFieldBytes.size)
            payloadData[0] = (identifierCode and 0xFF).toByte()
            System.arraycopy(uriFieldBytes, 0, payloadData, 1, uriFieldBytes.size)
            val payload = NdefPayload(payloadData)
            return record(
                type = NdefTypeField.uri,
                payload = payload,
                id = id,
                isFirstInMessage = isFirstInMessage,
                isLastInMessage = isLastInMessage
            )
        }

        /** Factory for Media Type text/json records from a JSON string */
        fun json(
            jsonString: String,
            id: NdefIdField? = null,
            isFirstInMessage: Boolean = true,
            isLastInMessage: Boolean = true
        ): NdefRecordSerializer {
            val payload = NdefPayload(jsonString.toByteArray(StandardCharsets.UTF_8))
            return record(
                type = NdefTypeField.textJson,
                payload = payload,
                id = id,
                isFirstInMessage = isFirstInMessage,
                isLastInMessage = isLastInMessage
            )
        }

        /** Factory for Media Type text/json records from a Map (parity with Dart) */
        fun json(
            jsonMap: Map<String, Any?>,
            id: NdefIdField? = null,
            isFirstInMessage: Boolean = true,
            isLastInMessage: Boolean = true
        ): NdefRecordSerializer {
            val jsonString = JSONObject(jsonMap).toString()
            return json(
                jsonString = jsonString,
                id = id,
                isFirstInMessage = isFirstInMessage,
                isLastInMessage = isLastInMessage
            )
        }

        fun fromBytes(rawRecord: Bytes, initialOffset: Int = 0): NdefRecordSerializer {
            var offset = initialOffset
            require(offset < rawRecord.size) { "Malformed NDEF: Buffer too short for flags." }

            val flags = NdefFlagByte.fromByte(rawRecord[offset++].toInt() and 0xFF)

            require(offset < rawRecord.size) { "Malformed NDEF: Not enough bytes for type length." }
            val typeLength = rawRecord[offset++].toInt() and 0xFF

            val payloadLength: Int
            if (flags.isShortRecord) {
                require(offset < rawRecord.size) { "Malformed NDEF: Not enough bytes for short payload length." }
                payloadLength = rawRecord[offset++].toInt() and 0xFF
            } else {
                require(offset + 3 < rawRecord.size) { "Malformed NDEF: Not enough bytes for long payload length." }
                val buffer = ByteBuffer.wrap(rawRecord, offset, 4).order(ByteOrder.BIG_ENDIAN)
                payloadLength = buffer.int
                offset += 4
            }

            val idLength = if (flags.hasId) {
                require(offset < rawRecord.size) { "Malformed NDEF: Not enough bytes for ID length." }
                rawRecord[offset++].toInt() and 0xFF
            } else 0

            require(offset + typeLength <= rawRecord.size) { "Malformed NDEF: Not enough bytes for type." }
            val typeBytes = rawRecord.sliceArray(offset until offset + typeLength)
            offset += typeLength
            val type = NdefTypeField.of(typeBytes, flags.tnf)

            val id = if (idLength > 0) {
                require(offset + idLength <= rawRecord.size) { "Malformed NDEF: Not enough bytes for ID." }
                val idBytes = rawRecord.sliceArray(offset until offset + idLength)
                offset += idLength
                NdefIdField(idBytes)
            } else null

            require(offset + payloadLength <= rawRecord.size) { "Malformed NDEF: Not enough bytes for payload." }
            val payload = if (payloadLength > 0) {
                val payloadBytes = rawRecord.sliceArray(offset until offset + payloadLength)
                NdefPayload(payloadBytes)
            } else null

            return NdefRecordSerializer(flags, type, payload, id)
        }

        fun chunkBegin(
            type: NdefTypeField,
            firstChunkPayload: NdefPayload,
            id: NdefIdField? = null,
            isFirstInMessage: Boolean = true
        ): NdefRecordSerializer {
            validateChunkBeginArgs(type)
            val hasId = id != null

            val flags = NdefFlagByte.chunk(
                tnf = type.tnf,
                isFirstChunk = true,
                isFirstMessageRecord = isFirstInMessage,
                hasId = hasId
            )

            return NdefRecordSerializer(flags, type, firstChunkPayload, id)
        }

        fun chunkIntermediate(intermediateChunkPayload: NdefPayload): NdefRecordSerializer {
            val flags = NdefFlagByte.chunk(isFirstChunk = false, isLastChunk = false)
            return NdefRecordSerializer(flags, NdefTypeField.unchanged, intermediateChunkPayload, null)
        }

        fun chunkEnd(
            lastChunkPayload: NdefPayload,
            isLastInMessage: Boolean = true
        ): NdefRecordSerializer {
            val flags = NdefFlagByte.chunk(
                isFirstChunk = false,
                isLastChunk = true,
                isLastMessageRecord = isLastInMessage
            )
            return NdefRecordSerializer(flags, NdefTypeField.unchanged, lastChunkPayload, null)
        }

        private fun validateRecordArgs(type: NdefTypeField, payload: NdefPayload?, id: NdefIdField?) {
            val tnf = type.tnf
            if (tnf == Tnf.EMPTY && (type.length > 0 || (payload?.length ?: 0) > 0 || id != null)) {
                throw IllegalArgumentException("Empty TNF record must have no type, payload, or id.")
            }
            if (tnf == Tnf.UNCHANGED) {
                throw IllegalArgumentException("Unchanged TNF is only for chunked records. Use chunk factories.")
            }
            if (tnf == Tnf.UNKNOWN && type.length > 0) {
                throw IllegalArgumentException("Unknown TNF must not have a Type field.")
            }
        }

        private fun validateChunkBeginArgs(type: NdefTypeField) {
            val tnf = type.tnf
            if (tnf == Tnf.EMPTY || tnf == Tnf.UNCHANGED || tnf == Tnf.UNKNOWN) {
                throw IllegalArgumentException("Invalid TNF for a starting chunk. Must be WKT, Media, URI, or External.")
            }
        }

    // Single source of truth for URI scheme ↔ code mappings (order matters for prefix matching)
    private val uriSchemesToCode = linkedMapOf(
            "http://www." to 0x01,
            "https://www." to 0x02,
            "http://" to 0x03,
            "https://" to 0x04,
            "tel:" to 0x05,
            "mailto:" to 0x06,
            "ftp://anonymous:anonymous@" to 0x07,
            "ftp://ftp." to 0x08,
            "ftps://" to 0x09,
            "sftp://" to 0x0A,
            "smb://" to 0x0B,
            "nfs://" to 0x0C,
            "ftp://" to 0x0D,
            "dav://" to 0x0E,
            "news:" to 0x0F,
            "telnet://" to 0x10,
            "imap:" to 0x11,
            "rtsp://" to 0x12,
            "urn:" to 0x13,
            "pop:" to 0x14,
            "sip:" to 0x15,
            "sips:" to 0x16,
            "tftp:" to 0x17,
            "btspp://" to 0x18,
            "btl2cap://" to 0x19,
            "btgoep://" to 0x1A,
            "tcpobex://" to 0x1B,
            "irdaobex://" to 0x1C,
            "file://" to 0x1D,
            "urn:epc:id:" to 0x1E,
            "urn:epc:tag:" to 0x1F,
            "urn:epc:pat:" to 0x20,
            "urn:epc:raw:" to 0x21,
            "urn:epc:" to 0x22,
            "urn:nfc:" to 0x23,
        )

    private val codeToUriScheme: Map<Int, String> = uriSchemesToCode.entries.associate { it.value to it.key }

        private fun getUriIdentifierCode(uri: String): Int {
            for ((prefix, code) in uriSchemesToCode) {
                if (uri.startsWith(prefix)) return code
            }
            return 0x00
        }

        private fun getUriField(uri: String, identifierCode: Int): String {
            if (identifierCode == 0x00) return uri
            val prefix = codeToUriScheme[identifierCode]
            return if (prefix != null && uri.startsWith(prefix)) uri.removePrefix(prefix) else uri
        }

        private fun reconstructUri(identifierCode: Int, uriField: String): String {
            val scheme = codeToUriScheme[identifierCode]
            return if (scheme != null) scheme + uriField else uriField
        }
    }

    // Convenience accessors mirroring Dart helpers
    fun textContent(): String? {
        if (type != NdefTypeField.text || payload == null) return null
        return try {
            val bytes = payload.buffer
            if (bytes.isEmpty()) return null
            val langLen = bytes[0].toInt() and 0x3F
            if (bytes.size < 1 + langLen) return null
            val textStart = 1 + langLen
            val textBytes = bytes.copyOfRange(textStart, bytes.size)
            String(textBytes, StandardCharsets.UTF_8)
        } catch (_: Exception) {
            null
        }
    }

    fun textLanguage(): String? {
        if (type != NdefTypeField.text || payload == null) return null
        return try {
            val bytes = payload.buffer
            if (bytes.isEmpty()) return null
            val langLen = bytes[0].toInt() and 0x3F
            if (bytes.size < 1 + langLen) return null
            val langBytes = bytes.copyOfRange(1, 1 + langLen)
            String(langBytes, StandardCharsets.UTF_8)
        } catch (_: Exception) {
            null
        }
    }

    fun uriContent(): String? {
        if (type != NdefTypeField.uri || payload == null) return null
        return try {
            val bytes = payload.buffer
            if (bytes.isEmpty()) return null
            val identifierCode = bytes[0].toInt() and 0xFF
            val uriFieldBytes = bytes.copyOfRange(1, bytes.size)
            val uriField = String(uriFieldBytes, StandardCharsets.UTF_8)
            Companion.reconstructUri(identifierCode, uriField)
        } catch (_: Exception) {
            null
        }
    }

    fun jsonContent(): JSONObject? {
        if (type != NdefTypeField.textJson || payload == null) return null
        return try {
            val jsonString = String(payload.buffer, StandardCharsets.UTF_8)
            JSONObject(jsonString)
        } catch (_: Exception) {
            null
        }
    }
}
