package io.flutter.plugins.nfc_host_card_emulation.file_access.serializers

import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduData
import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduSerializer
import io.flutter.plugins.nfc_host_card_emulation.app_layer.Bytes
import io.flutter.plugins.nfc_host_card_emulation.file_access.fields.*

sealed class ApduCommand(
    val cla: ApduClass,
    val ins: ApduInstruction,
    name: String
) : ApduSerializer(name) {
    companion object {
        fun fromBytes(rawCommand: Bytes): ApduCommand {
            require(rawCommand.size >= 4) { "Invalid APDU command: must be at least 4 bytes long. Got ${rawCommand.size} bytes." }

            val insByte = rawCommand[1].toInt() and 0xFF
            return when (insByte) {
                ApduInstruction.SELECT_BYTE -> SelectCommand.fromBytes(rawCommand)
                ApduInstruction.READ_BINARY_BYTE -> ReadBinaryCommand.fromBytes(rawCommand)
                ApduInstruction.UPDATE_BINARY_BYTE -> UpdateBinaryCommand.fromBytes(rawCommand)
                else -> UnknownCommand.fromBytes(rawCommand)
            }
        }
    }
}

class SelectCommand private constructor(
    val params: ApduParams,
    val lc: ApduLc,
    val data: ApduData
) : ApduCommand(ApduClass.standard, ApduInstruction.select, "SELECT Command") {
    companion object {
        internal fun fromBytes(rawCommand: Bytes): SelectCommand {
            require(rawCommand.size >= 5) { "Invalid SELECT command frame: expected at least 5 bytes, got ${rawCommand.size}." }
            val lcValue = rawCommand[4].toInt() and 0xFF
            require(rawCommand.size == 5 + lcValue) { "Invalid SELECT command frame: Lc value of $lcValue does not match data length of ${rawCommand.size - 5}." }

            val p1 = rawCommand[2].toInt() and 0xFF
            val p2 = rawCommand[3].toInt() and 0xFF
            val commandData = rawCommand.sliceArray(5 until 5 + lcValue)

            return SelectCommand(
                params = ApduParams(p1, p2, "P1-P2 (Parsed)"),
                lc = ApduLc(lcValue),
                data = ApduData("Data (Parsed)", commandData)
            )
        }
    }

    override fun setFields() {
        fields = listOf(cla, ins, params, lc, data)
    }
}

class ReadBinaryCommand private constructor(
    val params: ApduParams,
    val le: ApduLe
) : ApduCommand(ApduClass.standard, ApduInstruction.readBinary, "READ BINARY Command") {
    val offset: Int
        get() = ((params.buffer[0].toInt() and 0xFF) shl 8) or (params.buffer[1].toInt() and 0xFF)
    val lengthToRead: Int
        get() = le.buffer[0].toInt() and 0xFF

    companion object {
        internal fun fromBytes(rawCommand: Bytes): ReadBinaryCommand {
            require(rawCommand.size == 5) { "Invalid READ BINARY command frame: expected exactly 5 bytes, got ${rawCommand.size}." }
            val p1 = rawCommand[2].toInt() and 0xFF
            val p2 = rawCommand[3].toInt() and 0xFF
            val leValue = rawCommand[4].toInt() and 0xFF
            return ReadBinaryCommand(
                params = ApduParams(p1, p2, "P1-P2 (Parsed)"),
                le = ApduLe(leValue)
            )
        }
    }

    override fun setFields() {
        fields = listOf(cla, ins, params, le)
    }
}

class UpdateBinaryCommand private constructor(
    val params: ApduParams,
    val lc: ApduLc,
    val data: ApduData
) : ApduCommand(ApduClass.standard, ApduInstruction.updateBinary, "UPDATE BINARY Command") {
    val offset: Int
        get() = ((params.buffer[0].toInt() and 0xFF) shl 8) or (params.buffer[1].toInt() and 0xFF)
    val dataToWrite: Bytes
        get() = data.buffer

    companion object {
        internal fun fromBytes(rawCommand: Bytes): UpdateBinaryCommand {
            require(rawCommand.size >= 5) { "Invalid UPDATE BINARY command frame: expected at least 5 bytes, got ${rawCommand.size}." }
            val lcValue = rawCommand[4].toInt() and 0xFF
            require(rawCommand.size == 5 + lcValue) { "Invalid UPDATE BINARY command frame: Lc value of $lcValue does not match data length of ${rawCommand.size - 5}." }

            val p1 = rawCommand[2].toInt() and 0xFF
            val p2 = rawCommand[3].toInt() and 0xFF
            val commandData = rawCommand.sliceArray(5 until 5 + lcValue)

            return UpdateBinaryCommand(
                params = ApduParams(p1, p2, "P1-P2 (Parsed)"),
                lc = ApduLc(lcValue),
                data = ApduData("Data (Parsed)", commandData)
            )
        }
    }

    override fun setFields() {
        fields = listOf(cla, ins, params, lc, data)
    }
}

class UnknownCommand private constructor(
    insByte: Int,
    val data: ApduData?
) : ApduCommand(ApduClass.standard, ApduInstruction(insByte, "INS (Unknown)"), "Unknown Command") {
    companion object {
        internal fun fromBytes(rawCommand: Bytes): UnknownCommand {
            val insByte = rawCommand[1].toInt() and 0xFF
            val data = if (rawCommand.size > 4) {
                ApduData("Unknown Data", rawCommand.sliceArray(4 until rawCommand.size))
            } else {
                null
            }
            return UnknownCommand(insByte, data)
        }
    }

    override fun setFields() {
        fields = listOf(cla, ins, data)
    }
}