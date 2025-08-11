package com.viridian.flutter_hce.app_layer.ndef_format.serializers

import com.viridian.flutter_hce.app_layer.ApduSerializer
import com.viridian.flutter_hce.app_layer.Bytes
import com.viridian.flutter_hce.app_layer.ndef_format.fields.*
import java.nio.ByteBuffer
import java.nio.ByteOrder

class NdefRecordSerializer private constructor(
    val flags: NdefFlagByte,
    val type: NdefTypeField,
    val payload: NdefPayload?,
    val id: NdefIdField?
) : ApduSerializer("NDEF Record") {
    
    private val typeLength: NdefTypeLengthField = NdefTypeLengthField(type.length)
    private val payloadLength: NdefPayloadLengthField = NdefPayloadLengthField.create(payload?.length ?: 0)
    private val idLength: NdefIdLengthField? = if (id != null) NdefIdLengthField(id.length) else null

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
            val type = NdefTypeField(typeBytes, flags.tnf)

            val id = if (idLength > 0) {
                require(offset + idLength <= rawRecord.size) { "Malformed NDEF: Not enough bytes for ID." }
                val idBytes = rawRecord.sliceArray(offset until offset + idLength)
                offset += idLength
                NdefIdField(idBytes)
            } else null

            require(offset + payloadLength <= rawRecord.size) { "Malformed NDEF: Not enough bytes for payload." }
            val payloadBytes = rawRecord.sliceArray(offset until offset + payloadLength)
            val payload = NdefPayload(payloadBytes)

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
    }

    override fun setFields() {
        fields.clear()
        fields.add(flags)
        fields.add(typeLength)
        fields.add(payloadLength)
        
        if (flags.hasId) {
            fields.add(idLength)
        }
        
        if (type.length > 0) {
            fields.add(type)
        }
        
        if (flags.hasId) {
            fields.add(id)
        }
        
        if ((payload?.length ?: 0) > 0) {
            fields.add(payload)
        }
    }
}
