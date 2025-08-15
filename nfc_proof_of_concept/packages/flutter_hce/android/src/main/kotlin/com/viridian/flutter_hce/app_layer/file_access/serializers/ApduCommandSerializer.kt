package com.viridian.flutter_hce.app_layer.file_access.serializers

import com.viridian.flutter_hce.app_layer.ApduData
import com.viridian.flutter_hce.app_layer.ApduSerializer
import com.viridian.flutter_hce.app_layer.Bytes
import com.viridian.flutter_hce.app_layer.file_access.fields.*

abstract class ApduCommand(
    name: String,
    cla: ApduClass,
    ins: ApduInstruction
) : ApduSerializer(name) {
    // Register common header fields first
    protected val cla: ApduClass = register(cla)
    protected val ins: ApduInstruction = register(ins)

    companion object {
        /** Smart creator that mirrors the Dart factory, picking a concrete command */
        fun create(
            ins: ApduInstruction,
            params: ApduParams,
            cla: ApduClass? = null,
            lc: ApduLc? = null,
            data: ApduData? = null,
            le: ApduLe? = null
        ): ApduCommand {
            val effectiveCla = cla ?: ApduClass.standard
            return when (ins) {
                ApduInstruction.select -> {
                    requireNotNull(data) { "SELECT command requires data field" }
                    val effectiveLc = lc ?: ApduLc(data.length)
                    SelectCommand(
                        cla = effectiveCla,
                        params = params,
                        lc = effectiveLc,
                        data = data
                    )
                }
                ApduInstruction.readBinary -> {
                    requireNotNull(le) { "READ BINARY command requires Le field" }
                    ReadBinaryCommand(
                        cla = effectiveCla,
                        params = params,
                        le = le
                    )
                }
                ApduInstruction.updateBinary -> {
                    requireNotNull(data) { "UPDATE BINARY command requires data field" }
                    val effectiveLc = lc ?: ApduLc(data.length)
                    UpdateBinaryCommand(
                        cla = effectiveCla,
                        params = params,
                        lc = effectiveLc,
                        data = data
                    )
                }
                else -> {
                    UnknownCommand(
                        cla = effectiveCla,
                        ins = ins,
                        params = params,
                        data = data
                    )
                }
            }
        }

        /** Deserializer for raw bytes */
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

class SelectCommand(
    cla: ApduClass,
    val params: ApduParams,
    val lc: ApduLc,
    val data: ApduData
) : ApduCommand("SELECT Command", cla, ApduInstruction.select) {
    private val paramsField = register(params)
    private val lcField = register(lc)
    private val dataField = register(data)

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
                cla = ApduClass.standard,
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
}

class ReadBinaryCommand(
    cla: ApduClass,
    val params: ApduParams,
    val le: ApduLe
) : ApduCommand("READ BINARY Command", cla, ApduInstruction.readBinary) {
    private val paramsField = register(params)
    private val leField = register(le)

    val offset: Int
        get() = ((params.buffer[0].toInt() and 0xFF) shl 8) or (params.buffer[1].toInt() and 0xFF)

    val lengthToRead: Int
        get() = le.buffer[0].toInt() and 0xFF

    companion object {
        fun fromBytes(rawCommand: Bytes): ReadBinaryCommand {
            require(rawCommand.size == 5) {
                "Invalid READ BINARY command frame: expected exactly 5 bytes, got ${rawCommand.size}."
            }
            return ReadBinaryCommand(
                cla = ApduClass.standard,
                params = ApduParams(
                    rawCommand[2].toInt() and 0xFF,
                    rawCommand[3].toInt() and 0xFF,
                    "P1-P2 (Parsed)"
                ),
                le = ApduLe(rawCommand[4].toInt() and 0xFF)
            )
        }
    }
}

class UpdateBinaryCommand(
    cla: ApduClass,
    val params: ApduParams,
    val lc: ApduLc,
    val data: ApduData
) : ApduCommand("UPDATE BINARY Command", cla, ApduInstruction.updateBinary) {
    private val paramsField = register(params)
    private val lcField = register(lc)
    private val dataField = register(data)

    val offset: Int
        get() = ((params.buffer[0].toInt() and 0xFF) shl 8) or (params.buffer[1].toInt() and 0xFF)
    
    val dataToWrite: Bytes
        get() = data.buffer

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
                cla = ApduClass.standard,
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
}

class UnknownCommand(
    cla: ApduClass,
    ins: ApduInstruction,
    val params: ApduParams,
    private val data: ApduData?
) : ApduCommand("Unknown Command", cla, ins) {
    private val paramsField = register(params)
    private val dataField = register(data)

    companion object {
        fun fromBytes(rawCommand: Bytes): UnknownCommand {
            val ins = ApduInstruction.fromByte(rawCommand[1].toInt() and 0xFF)
            val params = ApduParams(
                rawCommand[2].toInt() and 0xFF,
                rawCommand[3].toInt() and 0xFF,
                "P1-P2 (Parsed)"
            )
            val data = if (rawCommand.size > 4) {
                ApduData(rawCommand.sliceArray(4 until rawCommand.size), "Unknown Data")
            } else null
            return UnknownCommand(
                cla = ApduClass.standard,
                ins = ins,
                params = params,
                data = data
            )
        }
    }
}
