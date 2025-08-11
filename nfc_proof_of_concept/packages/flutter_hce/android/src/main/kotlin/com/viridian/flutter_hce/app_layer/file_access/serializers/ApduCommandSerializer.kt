package com.viridian.flutter_hce.app_layer.file_access.serializers

import com.viridian.flutter_hce.app_layer.ApduData
import com.viridian.flutter_hce.app_layer.ApduSerializer
import com.viridian.flutter_hce.app_layer.Bytes
import com.viridian.flutter_hce.app_layer.file_access.fields.*

abstract class ApduCommand(
    private val cla: ApduClass,
    private val ins: ApduInstruction,
    name: String
) : ApduSerializer(name) {

    companion object {
        fun fromBytes(rawCommand: Bytes): ApduCommand {
            require(rawCommand.size >= 4) { 
                "Invalid APDU command: must be at least 4 bytes long. Got ${rawCommand.size} bytes." 
            }

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
        fun fromBytes(rawCommand: Bytes): SelectCommand {
            require(rawCommand.size >= 5) {
                "Invalid SELECT command frame: expected at least 5 bytes, got ${rawCommand.size}."
            }
            val lcValue = rawCommand[4].toInt() and 0xFF
            require(rawCommand.size == 5 + lcValue) {
                "Invalid SELECT command frame: Lc value of $lcValue does not match data length of ${rawCommand.size - 5}."
            }

            return SelectCommand(
                params = ApduParams(
                    rawCommand[2].toInt() and 0xFF,
                    rawCommand[3].toInt() and 0xFF,
                    "P1-P2 (Parsed)"
                ),
                lc = ApduLc(lcValue),
                data = ApduData(rawCommand.sliceArray(5 until 5 + lcValue), "Data (Parsed)")
            )
        }
    }

    override fun setFields() {
        fields.clear()
        fields.addAll(listOf(
            ApduClass.standard,
            ApduInstruction.select,
            params,
            lc,
            data
        ))
    }
}

class ReadBinaryCommand private constructor(
    val params: ApduParams,
    val le: ApduLe
) : ApduCommand(ApduClass.standard, ApduInstruction.readBinary, "READ BINARY Command") {

    val offset: Int
        get() = ((params.toByteArray()[0].toInt() and 0xFF) shl 8) or (params.toByteArray()[1].toInt() and 0xFF)

    val lengthToRead: Int
        get() = le.toByteArray()[0].toInt() and 0xFF

    companion object {
        fun fromBytes(rawCommand: Bytes): ReadBinaryCommand {
            require(rawCommand.size == 5) {
                "Invalid READ BINARY command frame: expected exactly 5 bytes, got ${rawCommand.size}."
            }
            return ReadBinaryCommand(
                params = ApduParams(
                    rawCommand[2].toInt() and 0xFF,
                    rawCommand[3].toInt() and 0xFF,
                    "P1-P2 (Parsed)"
                ),
                le = ApduLe(rawCommand[4].toInt() and 0xFF)
            )
        }
    }

    override fun setFields() {
        fields.clear()
        fields.addAll(listOf(
            ApduClass.standard,
            ApduInstruction.readBinary,
            params,
            le
        ))
    }
}

class UpdateBinaryCommand private constructor(
    val params: ApduParams,
    val lc: ApduLc,
    val data: ApduData
) : ApduCommand(ApduClass.standard, ApduInstruction.updateBinary, "UPDATE BINARY Command") {

    val offset: Int
        get() = ((params.toByteArray()[0].toInt() and 0xFF) shl 8) or (params.toByteArray()[1].toInt() and 0xFF)
    
    val dataToWrite: Bytes
        get() = data.toByteArray()

    companion object {
        fun fromBytes(rawCommand: Bytes): UpdateBinaryCommand {
            require(rawCommand.size >= 5) {
                "Invalid UPDATE BINARY command frame: expected at least 5 bytes, got ${rawCommand.size}."
            }
            val lcValue = rawCommand[4].toInt() and 0xFF
            require(rawCommand.size == 5 + lcValue) {
                "Invalid UPDATE BINARY command frame: Lc value of $lcValue does not match data length of ${rawCommand.size - 5}."
            }

            return UpdateBinaryCommand(
                params = ApduParams(
                    rawCommand[2].toInt() and 0xFF,
                    rawCommand[3].toInt() and 0xFF,
                    "P1-P2 (Parsed)"
                ),
                lc = ApduLc(lcValue),
                data = ApduData(rawCommand.sliceArray(5 until 5 + lcValue), "Data (Parsed)")
            )
        }
    }

    override fun setFields() {
        fields.clear()
        fields.addAll(listOf(
            ApduClass.standard,
            ApduInstruction.updateBinary,
            params,
            lc,
            data
        ))
    }
}

class UnknownCommand private constructor(
    private val data: ApduData?
) : ApduCommand(ApduClass.standard, ApduInstruction(0x00, "INS (Unknown)", true), "Unknown Command") {

    companion object {
        fun fromBytes(rawCommand: Bytes): UnknownCommand {
            val data = if (rawCommand.size > 4) {
                ApduData(rawCommand.sliceArray(4 until rawCommand.size), "Unknown Data")
            } else null

            return UnknownCommand(data)
        }
    }

    override fun setFields() {
        fields.clear()
        fields.addAll(listOfNotNull(
            ApduClass.standard,
            ApduInstruction(0x00, "INS (Unknown)", true),
            data
        ))
    }
}
