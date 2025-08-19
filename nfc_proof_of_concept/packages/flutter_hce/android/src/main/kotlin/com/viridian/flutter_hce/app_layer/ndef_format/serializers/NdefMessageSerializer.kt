package com.viridian.flutter_hce.app_layer.ndef_format.serializers

import com.viridian.flutter_hce.app_layer.ApduSerializer
import com.viridian.flutter_hce.app_layer.Bytes
import com.viridian.flutter_hce.app_layer.ndef_format.fields.*

class NdefFormatException(message: String) : Exception(message)

private enum class ChunkedRecordState { NOT_IN_CHUNK, AWAITING_MIDDLE_OR_END_CHUNK }

private class NdefParser(private val rawMessage: Bytes) {
    private var offset = 0
    private var chunkState = ChunkedRecordState.NOT_IN_CHUNK
    private val reassembledPayload = mutableListOf<Byte>()
    private var reassembledType: NdefTypeField? = null
    private var reassembledId: NdefIdField? = null
    private var isFirstRecordInMessage = true

    fun parse(): List<NdefRecordSerializer> {
        val completeRecords = mutableListOf<NdefRecordSerializer>()
        while (offset < rawMessage.size) {
            val record = parseNextRecord()
            if (record != null) {
                completeRecords.add(record)
            }
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
        val (payloadLength, _) = readPayloadLength(flags)
        val idLength = readIdLength(flags)
        val type = readType(flags, typeLength)
        val id = readId(flags, idLength)
        val payload = readPayload(payloadLength)

        return processRecord(flags, type, payload, id)
    }

    private fun processRecord(
        flags: NdefFlagByte,
        type: NdefTypeField,
        payload: NdefPayload?,
        id: NdefIdField?
    ): NdefRecordSerializer? {
        return when (chunkState) {
            ChunkedRecordState.NOT_IN_CHUNK -> {
                if (flags.isChunked) {
                    validateFirstChunk(flags)
                    chunkState = ChunkedRecordState.AWAITING_MIDDLE_OR_END_CHUNK
                    reassembledPayload.clear()
                    reassembledPayload.addAll((payload?.buffer ?: ByteArray(0)).toList())
                    reassembledType = type
                    reassembledId = id
                    null
                } else {
                    val isLast = offset >= rawMessage.size
                    val record = NdefRecordSerializer.record(
                        type = type,
                        payload = payload,
                        id = id,
                        isFirstInMessage = isFirstRecordInMessage,
                        isLastInMessage = isLast
                    )
                    isFirstRecordInMessage = false
                    record
                }
            }
            ChunkedRecordState.AWAITING_MIDDLE_OR_END_CHUNK -> {
                validateSubsequentChunk(flags)
                reassembledPayload.addAll((payload?.buffer ?: ByteArray(0)).toList())
                if (flags.isChunked) {
                    null
                } else {
                    chunkState = ChunkedRecordState.NOT_IN_CHUNK
                    val finalPayload = NdefPayload(reassembledPayload.toByteArray())
                    val record = NdefRecordSerializer.record(
                        type = reassembledType!!,
                        payload = finalPayload,
                        id = reassembledId,
                        isFirstInMessage = isFirstRecordInMessage,
                        isLastInMessage = flags.isMessageEnd
                    )
                    isFirstRecordInMessage = false
                    record
                }
            }
        }
    }

    private fun readFlags(): NdefFlagByte {
        if (offset >= rawMessage.size) throw NdefFormatException("Unexpected end of data when reading flags.")
        return NdefFlagByte.fromByte(rawMessage[offset++].toInt() and 0xFF)
    }

    private fun readTypeLength(flags: NdefFlagByte): Int {
        if (flags.tnf == Tnf.EMPTY || 
            (chunkState == ChunkedRecordState.AWAITING_MIDDLE_OR_END_CHUNK && flags.tnf == Tnf.UNCHANGED)) return 0
        if (offset >= rawMessage.size) throw NdefFormatException("Unexpected end of data when reading type length.")
        return rawMessage[offset++].toInt() and 0xFF
    }

    private fun readPayloadLength(flags: NdefFlagByte): Pair<Int, Int> {
        return if (flags.isShortRecord) {
            if (offset >= rawMessage.size) throw NdefFormatException("Unexpected end of data for short payload length.")
            Pair(rawMessage[offset++].toInt() and 0xFF, 1)
        } else {
            if (offset + 3 >= rawMessage.size) throw NdefFormatException("Unexpected end of data for long payload length.")
            val length = ((rawMessage[offset].toInt() and 0xFF) shl 24) or
                        ((rawMessage[offset + 1].toInt() and 0xFF) shl 16) or
                        ((rawMessage[offset + 2].toInt() and 0xFF) shl 8) or
                        (rawMessage[offset + 3].toInt() and 0xFF)
            offset += 4
            Pair(length, 4)
        }
    }

    private fun readIdLength(flags: NdefFlagByte): Int {
        if (!flags.hasId) return 0
        if (chunkState == ChunkedRecordState.AWAITING_MIDDLE_OR_END_CHUNK) {
            throw NdefFormatException("Invalid chunk: ID length must only be present in the first chunk.")
        }
        if (offset >= rawMessage.size) throw NdefFormatException("Unexpected end of data when reading ID length.")
        return rawMessage[offset++].toInt() and 0xFF
    }

    private fun readType(flags: NdefFlagByte, length: Int): NdefTypeField {
        if (length == 0) return NdefTypeField(ByteArray(0), flags.tnf)
        if (chunkState == ChunkedRecordState.AWAITING_MIDDLE_OR_END_CHUNK) {
            throw NdefFormatException("Invalid chunk: Type must only be present in the first chunk.")
        }
        if (offset + length > rawMessage.size) throw NdefFormatException("Unexpected end of data when reading type.")
        val typeBytes = rawMessage.sliceArray(offset until offset + length)
        offset += length
        return NdefTypeField(typeBytes, flags.tnf)
    }

    private fun readId(flags: NdefFlagByte, length: Int): NdefIdField? {
        if (!flags.hasId || length == 0) return null
        if (offset + length > rawMessage.size) throw NdefFormatException("Unexpected end of data when reading ID.")
        val idBytes = rawMessage.sliceArray(offset until offset + length)
        offset += length
        return NdefIdField(idBytes)
    }

    private fun readPayload(length: Int): NdefPayload? {
        if (length == 0) return null
        if (offset + length > rawMessage.size) throw NdefFormatException("Unexpected end of data when reading payload.")
        val payloadBytes = rawMessage.sliceArray(offset until offset + length)
        offset += length
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


class NdefMessageSerializer private constructor(
    private val records: List<NdefRecordSerializer>
) : ApduSerializer("NDEF Message") {

    init {
        for (rec in records) {
            register(rec)
        }
    }

    companion object {
        fun fromBytes(rawMessage: Bytes): NdefMessageSerializer {
            require(rawMessage.isNotEmpty()) { "Cannot parse an empty NDEF message." }
            val parser = NdefParser(rawMessage)
            val records = parser.parse()
            require(records.isNotEmpty()) { "Failed to parse any valid records from the NDEF message." }
            return NdefMessageSerializer(records)
        }

        fun fromRecords(records: List<NdefRecordSerializer>): NdefMessageSerializer {
            require(records.isNotEmpty()) { "Cannot create an NDEF message with zero records." }
            return NdefMessageSerializer(records)
        }
    }
}
