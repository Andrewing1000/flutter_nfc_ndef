package com.viridian.flutter_hce.app_layer

import com.viridian.flutter_hce.app_layer.file_access.serializers.*
import com.viridian.flutter_hce.app_layer.ndef_format.serializers.NdefMessageSerializer
import kotlin.math.min

private enum class HceState {
    IDLE,
    APP_SELECTED,
    CC_SELECTED,
    NDEF_SELECTED
}

private class NdefFile(message: NdefMessageSerializer, val maxSize: Int) {
    private lateinit var bytes: Bytes

    val buffer: Bytes get() = bytes.copyOf()
    val currentSize: Int get() = bytes.size

    init {
        update(message)
    }

    fun update(message: NdefMessageSerializer) {
        val messageBytes = message.toByteArray()
        val nlen = messageBytes.size

        if (nlen + 2 > maxSize) {
            throw IllegalArgumentException(
                "NDEF message size ($nlen bytes) exceeds the max file size ($maxSize bytes) defined in the CC."
            )
        }

        val nlenBytes = ByteArray(2)
        nlenBytes[0] = ((nlen shr 8) and 0xFF).toByte()
        nlenBytes[1] = (nlen and 0xFF).toByte()

        bytes = nlenBytes + messageBytes
    }
}

class HceStateMachine(
    private val aid: ByteArray,
    initialMessage: NdefMessageSerializer,
    isWritable: Boolean = false,
    maxNdefFileSize: Int = 2048 // 2KB
) {
    private var currentState = HceState.IDLE

    val capabilityContainer: CapabilityContainer = CapabilityContainer(
        fileDescriptors = listOf(
            FileControlTlv.ndef(
                maxNdefFileSize = maxNdefFileSize,
                isNdefWritable = isWritable
            )
        )
    )

    private val ndefFile = NdefFile(initialMessage, maxNdefFileSize)

    /**
     * Resets the state machine to its initial state.
     * Call this when the NFC field is deactivated.
     */
    fun onDeactivated() {
        currentState = HceState.IDLE
    }

    /**
     * The main entry point for processing an incoming APDU command.
     * Takes a raw command and returns a raw response.
     */
    fun processCommand(rawCommand: Bytes): Bytes {
        return try {
            val command = ApduCommand.fromBytes(rawCommand)
            val response = handleCommand(command)
            response.toByteArray()
        } catch (e: IllegalArgumentException) {
            throw HceException(HceErrorCode.INVALID_NDEF_FORMAT, "APDU Parsing Error", e.message)
        } catch (e: NotImplementedError) {
            throw HceException(HceErrorCode.INVALID_STATE, "Unsupported instruction", e.message)
        } catch (e: Exception) {
            throw HceException(HceErrorCode.UNKNOWN, "Unexpected FSM error", e.message)
        }
    }

    /**
     * The core FSM logic. Routes commands based on the current state.
     */
    private fun handleCommand(command: ApduCommand): ApduResponse {
        return when (currentState) {
            HceState.IDLE -> handleIdleState(command)
            HceState.APP_SELECTED -> handleAppSelectedState(command)
            HceState.CC_SELECTED -> handleCcSelectedState(command)
            HceState.NDEF_SELECTED -> handleNdefSelectedState(command)
        }
    }

    private fun handleIdleState(command: ApduCommand): ApduResponse {
        if (command is SelectCommand) {
            if (command.params.toByteArray().contentEquals(
                    byteArrayOf(0x04, 0x00) // ApduParams.byName equivalent
                ) && isNdefAid(command.data.toByteArray())
            ) {
                currentState = HceState.APP_SELECTED
                return ApduResponse.success()
            }
        }
        throw HceException(HceErrorCode.INVALID_STATE, "Invalid command in IDLE state")
    }

    private fun handleAppSelectedState(command: ApduCommand): ApduResponse {
        if (command is SelectCommand && command.params.toByteArray().contentEquals(
                byteArrayOf(0x00, 0x0C) // ApduParams.byFileId equivalent
            )
        ) {
            val data = command.data.toByteArray()
            if (data.size < 2) {
                throw HceException(HceErrorCode.INVALID_FILE_ID, "File ID must be 2 bytes")
            }

            val fileId = ((data[0].toInt() and 0xFF) shl 8) or (data[1].toInt() and 0xFF)
            when (fileId) {
                0xE103 -> { // CC File
                    currentState = HceState.CC_SELECTED
                    return ApduResponse.success()
                }
                0xE104 -> { // NDEF File
                    currentState = HceState.NDEF_SELECTED
                    return ApduResponse.success()
                }
                else -> {
                    throw HceException(
                        HceErrorCode.FILE_NOT_FOUND,
                        "File ID 0x${fileId.toString(16).padStart(4, '0').toUpperCase(java.util.Locale.ROOT)} not found"
                    )
                }
            }
        }
        throw HceException(HceErrorCode.INVALID_STATE, "Invalid command in APP_SELECTED state")
    }

    private fun handleCcSelectedState(command: ApduCommand): ApduResponse {
        if (command is ReadBinaryCommand) {
            return processRead(command, capabilityContainer.toByteArray())
        }
        throw HceException(
            HceErrorCode.INVALID_STATE,
            "Only READ_BINARY commands are allowed in CC_SELECTED state"
        )
    }

    private fun handleNdefSelectedState(command: ApduCommand): ApduResponse {
        if (command is ReadBinaryCommand) {
            return processRead(command, ndefFile.buffer)
        }
        throw HceException(
            HceErrorCode.INVALID_STATE,
            "Only READ_BINARY commands are allowed in NDEF_SELECTED state"
        )
    }

    private fun processRead(command: ReadBinaryCommand, file: Bytes): ApduResponse {
        val offset = command.offset
        if (offset >= file.size) {
            throw HceException(
                HceErrorCode.INVALID_STATE,
                "Read offset $offset exceeds file length ${file.size}"
            )
        }

        val lengthToRead = if (command.lengthToRead == 0) 256 else command.lengthToRead
        if (lengthToRead > 256) {
            throw HceException(
                HceErrorCode.BUFFER_OVERFLOW,
                "Requested length $lengthToRead exceeds maximum allowed (256 bytes)"
            )
        }

        val bytesRemaining = file.size - offset
        val bytesToSend = min(lengthToRead, bytesRemaining)

        val chunk = file.sliceArray(offset until offset + bytesToSend)
        return ApduResponse.success(chunk)
    }

    private fun isNdefAid(aidToCheck: Bytes): Boolean {
        if (aidToCheck.size != aid.size) return false
        for (i in aidToCheck.indices) {
            if (aidToCheck[i] != aid[i]) return false
        }
        return true
    }
}
