package io.flutter.plugins.nfc_host_card_emulation.ndef_format.serializers

import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduSerializer
import io.flutter.plugins.nfc_host_card_emulation.ndef_format.fields.*

class NdefRecordSerializer private constructor(
    private val flags: NdefFlagByte,
    private val type: NdefTypeField,
    private val payload: NdefPayload?,
    private val id: NdefIdField?
) : ApduSerializer("NDEF Record") {

    private val typeLength: NdefTypeLengthField = NdefTypeLengthField(type.length)
    private val payloadLength: NdefPayloadLengthField = NdefPayloadLengthField.of(payload?.length?.toLong() ?: 0)
    private val idLength: NdefIdLengthField? = id?.let { NdefIdLengthField(it.length) }

    companion object {
        @JvmStatic
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

            return NdefRecordSerializer(
                flags = flags,
                type = type,
                payload = payload,
                id = id
            )
        }

        @JvmStatic
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

            return NdefRecordSerializer(
                flags = flags,
                type = type,
                payload = firstChunkPayload,
                id = id
            )
        }

        @JvmStatic
        fun chunkIntermediate(
            intermediateChunkPayload: NdefPayload
        ): NdefRecordSerializer {
            val flags = NdefFlagByte.chunk(isFirstChunk = false, isLastChunk = false)
            return NdefRecordSerializer(
                flags = flags,
                type = NdefTypeField.unchanged,
                payload = intermediateChunkPayload,
                id = null
            )
        }

        @JvmStatic
        fun chunkEnd(
            lastChunkPayload: NdefPayload,
            isLastInMessage: Boolean = true
        ): NdefRecordSerializer {
            val flags = NdefFlagByte.chunk(
                isFirstChunk = false,
                isLastChunk = true,
                isLastMessageRecord = isLastInMessage
            )
            return NdefRecordSerializer(
                flags = flags,
                type = NdefTypeField.unchanged,
                payload = lastChunkPayload,
                id = null
            )
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
        fields = listOf(
            flags,
            typeLength,
            payloadLength,
            if (flags.hasId) idLength else null,
            if (type.length > 0) type else null,
            if (flags.hasId) id else null,
            if ((payload?.length ?: 0) > 0) payload else null
        )
    }
}