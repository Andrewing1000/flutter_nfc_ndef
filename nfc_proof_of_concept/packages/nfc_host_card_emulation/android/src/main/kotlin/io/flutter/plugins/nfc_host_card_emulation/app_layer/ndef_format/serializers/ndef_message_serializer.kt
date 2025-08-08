package io.flutter.plugins.nfc_host_card_emulation.ndef_format

import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduSerializer
import io.flutter.plugins.nfc_host_card_emulation.app_layer.Bytes
import io.flutter.plugins.nfc_host_card_emulation.ndef_format.fields.*
import io.flutter.plugins.nfc_host_card_emulation.ndef_format.serializers.NdefRecordSerializer
import java.io.ByteArrayOutputStream

class NdefFormatException(message: String) : Exception(message)

private enum class ChunkedRecordState {
    NOT_IN_CHUNK,
    AWAITING_MIDDLE_OR_END_CHUNK
}

private class NdefParser(private val rawMessage: Bytes) {
    private var offset = 0
    private var chunkState = ChunkedRecordState.NOT_IN_CHUNK
    private var reassembledPayload: ByteArrayOutputStream? = null
    private var reassembledType: NdefTypeField? = null
    private var reassembledId: NdefIdField? = null
    private var isFirstRecordInMessage = true

    fun parse(): List<NdefRecordSerializer> {
        val completeRecords = mutableListOf<NdefRecordSerializer>()
        while (offset < rawMessage.size) {
            val record = parseNextRecord()
            record?.let { completeRecords.add(it) }
            if (record?.flags?.isMessageEnd == true) break
        }

        if (chunkState == ChunkedRecordState.AWAITING_MIDDLE_OR_END_CHUNK) {
            throw NdefFormatException("Invalid NDEF message: message ends with an incomplete chunk sequence.")
        }

        return completeRecords
    }

    private fun parseNextRecord(): NdefRecordSerializer? {
        val flags = readFlags()
        val typeLength = readTypeLength(flags)
        val (payloadLength, payloadLengthBytes) = readPayloadLength(flags)
        val idLength = readIdLength(flags)
        val type = readType(flags, typeLength)
        val id = readId(flags, idLength)
        val payload = readPayload(payloadLength)

        return processRecord(flags, type, payload, id)
    }

    private fun processRecord(flags: NdefFlagByte, type: NdefTypeField, payload: NdefPayload?, id: NdefIdField?): NdefRecordSerializer? {
        when (chunkState) {
            ChunkedRecordState.NOT_IN_CHUNK -> {
                if (flags.isChunked) {
                    validateFirstChunk(flags)
                    chunkState = ChunkedRecordState.AWAITING_MIDDLE_OR_END_CHUNK
                    reassembledPayload = ByteArrayOutputStream().apply { payload?.buffer?.let { write(it) } }
                    reassembledType = type
                    reassembledId = id
                    return null
                } else {
                    val isLast = offset >= rawMessage.size
                    val record = NdefRecordSerializer.record(type, payload, id, isFirstRecordInMessage, isLast)
                    isFirstRecordInMessage = false
                    return record
                }
            }
            ChunkedRecordState.AWAITING_MIDDLE_OR_END_CHUNK -> {
                validateSubsequentChunk(flags)
                reassembledPayload?.write(payload?.buffer ?: byteArrayOf())
                if (flags.isChunked) {
                    return null
                } else {
                    chunkState = ChunkedRecordState.NOT_IN_CHUNK
                    val finalPayload = NdefPayload(reassembledPayload?.toByteArray() ?: byteArrayOf())
                    val record = NdefRecordSerializer.record(reassembledType!!, finalPayload, reassembledId, isFirstRecordInMessage, flags.isMessageEnd)
                    isFirstRecordInMessage = false
                    return record
                }
            }
        }
    }

    private fun readFlags(): NdefFlagByte {
        if (offset >= rawMessage.size) throw NdefFormatException("Unexpected end of data when reading flags.")
        return NdefFlagByte.fromByte(rawMessage[offset++])
    }

    private fun readTypeLength(flags: NdefFlagByte): Int {
        if (flags.tnf == Tnf.EMPTY || (chunkState == ChunkedRecordState.AWAITING_MIDDLE_OR_END_CHUNK && flags.tnf == Tnf.UNCHANGED)) return 0
        if (offset >= rawMessage.size) throw NdefFormatException("Unexpected end of data when reading type length.")
        return rawMessage[offset++].toInt() and 0xFF
    }

    private fun readPayloadLength(flags: NdefFlagByte): Pair<Long, Int> {
        val (field, bytesRead) = NdefPayloadLengthField.fromBytes(flags.isShortRecord, rawMessage, offset)
        offset += bytesRead
        return Pair(field.getValue(), bytesRead)
    }

    private fun readIdLength(flags: NdefFlagByte): Int {
        if (!flags.hasId) return 0
        if (chunkState == ChunkedRecordState.AWAITING_MIDDLE_OR_END_CHUNK) throw NdefFormatException("Invalid chunk: ID length must only be present in the first chunk.")
        if (offset >= rawMessage.size) throw NdefFormatException("Unexpected end of data when reading ID length.")
        return rawMessage[offset++].toInt() and 0xFF
    }

    private fun readType(flags: NdefFlagByte, length: Int): NdefTypeField {
        if (length == 0) return NdefTypeField.fromBytes(byteArrayOf(), flags.tnf)
        if (chunkState == ChunkedRecordState.AWAITING_MIDDLE_OR_END_CHUNK) throw NdefFormatException("Invalid chunk: Type must only be present in the first chunk.")
        if (offset + length > rawMessage.size) throw NdefFormatException("Unexpected end of data when reading type.")
        val typeBytes = rawMessage.sliceArray(offset until offset + length)
        offset += length
        return NdefTypeField.fromBytes(typeBytes, flags.tnf)
    }
    
    private fun readId(flags: NdefFlagByte, length: Int): NdefIdField? {
        if (!flags.hasId || length == 0) return null
        if (offset + length > rawMessage.size) throw NdefFormatException("Unexpected end of data when reading ID.")
        val idBytes = rawMessage.sliceArray(offset until offset + length)
        offset += length
        return NdefIdField(idBytes)
    }

    private fun readPayload(length: Long): NdefPayload? {
        if (length == 0L) return null
        if (offset + length > rawMessage.size) throw NdefFormatException("Unexpected end of data when reading payload.")
        val payloadBytes = rawMessage.sliceArray(offset until offset + length.toInt())
        offset += length.toInt()
        return NdefPayload(payloadBytes)
    }

    private fun validateFirstChunk(flags: NdefFlagByte) {
        if (flags.tnf == Tnf.EMPTY || flags.tnf == Tnf.UNCHANGED) {
            throw NdefFormatException("Invalid first chunk: TNF cannot be Empty or Unchanged.")
        }
    }

    private fun validateSubsequentChunk(flags: NdefFlagByte) {
        if (flags.tnf != Tnf.UNCHANGED) {
            throw NdefFormatException("Invalid subsequent chunk: TNF must be Unchanged.")
        }
        if (flags.hasId) {
            throw NdefFormatException("Invalid subsequent chunk: ID field is not allowed.")
        }
    }
}

data class NdefRecordData(val type: NdefTypeField, val payload: NdefPayload?, val id: NdefIdField?)

class NdefMessageSerializer private constructor(private val records: List<NdefRecordSerializer>) : ApduSerializer("NDEF Message") {
    fun getRecordsData(): List<NdefRecordData> = records.map { it.toData() }

    companion object {
        @JvmStatic
        fun fromBytes(rawMessage: Bytes): NdefMessageSerializer {
            require(rawMessage.isNotEmpty()) { "Cannot parse an empty NDEF message." }
            val parser = NdefParser(rawMessage)
            val parsedRecords = parser.parse()
            require(parsedRecords.isNotEmpty()) { "Failed to parse any valid records from the NDEF message." }
            return NdefMessageSerializer(parsedRecords)
        }

        @JvmStatic
        fun fromRecords(recordData: List<NdefRecordData>): NdefMessageSerializer {
            require(recordData.isNotEmpty()) { "Cannot create an NDEF message with zero records." }
            val serializedRecords = recordData.mapIndexed { index, data ->
                NdefRecordSerializer.record(
                    type = data.type,
                    payload = data.payload,
                    id = data.id,
                    isFirstInMessage = (index == 0),
                    isLastInMessage = (index == recordData.lastIndex)
                )
            }
            return NdefMessageSerializer(serializedRecords)
        }
    }

    override fun setFields() {
        fields = records
    }
}