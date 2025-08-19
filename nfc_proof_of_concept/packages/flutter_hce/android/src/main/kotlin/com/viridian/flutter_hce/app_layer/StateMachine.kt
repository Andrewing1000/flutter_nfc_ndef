package com.viridian.flutter_hce.app_layer

import com.viridian.flutter_hce.app_layer.file_access.fields.ApduParams
import com.viridian.flutter_hce.app_layer.file_access.fields.ApduStatusWord
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
    private var bytes: Bytes
    private var inWriteSession: Boolean = false
    private var stagedPayload: MutableList<Byte> = mutableListOf()

    val buffer: Bytes get() = bytes.copyOf()
    val currentSize: Int get() = bytes.size

    init {
        bytes = buildBytes(message)
    }

    private fun buildBytes(message: NdefMessageSerializer): Bytes {
        val messageBytes = message.buffer
        val nlen = messageBytes.size
        require(nlen + 2 <= maxSize) {
            "NDEF message size ($nlen bytes) exceeds the max file size ($maxSize bytes) defined in the CC."
        }
    val result = ByteArray(2 + messageBytes.size)
    result[0] = ((nlen shr 8) and 0xFF).toByte()
    result[1] = (nlen and 0xFF).toByte()
    System.arraycopy(messageBytes, 0, result, 2, messageBytes.size)
    return result
    }

    fun update(message: NdefMessageSerializer) {
        bytes = buildBytes(message)
        inWriteSession = false
        stagedPayload.clear()
    }

    fun beginWriteSession() {
        // Set NLEN=0 to mark file as empty during write, per NFC Forum Type 4
        bytes = byteArrayOf(0x00, 0x00)
        inWriteSession = true
        stagedPayload.clear()
    }

    fun writeData(offset: Int, data: Bytes): Boolean {
        if (!inWriteSession) return false
        if (offset < 2) return false // Only NLEN is at 0..1; data must go at >=2
        val payloadOffset = offset - 2
        val endIndex = payloadOffset + data.size
        if (2 + endIndex > maxSize) return false
        // Ensure capacity
        if (stagedPayload.size < endIndex) {
            // grow with zeros up to endIndex
            val toAdd = endIndex - stagedPayload.size
            repeat(toAdd) { stagedPayload.add(0) }
        }
        for (i in data.indices) {
            stagedPayload[payloadOffset + i] = data[i]
        }
        return true
    }

    fun finalizeWrite(nlen: Int): Boolean {
        if (!inWriteSession) return false
        if (nlen < 0 || 2 + nlen > maxSize) return false
        if (stagedPayload.size < nlen) return false
        val finalPayload = ByteArray(nlen)
        for (i in 0 until nlen) {
            finalPayload[i] = stagedPayload[i]
        }
        val result = ByteArray(2 + nlen)
        result[0] = ((nlen shr 8) and 0xFF).toByte()
        result[1] = (nlen and 0xFF).toByte()
        System.arraycopy(finalPayload, 0, result, 2, nlen)
        bytes = result
        inWriteSession = false
        stagedPayload.clear()
        return true
    }
}

class HceStateMachine(
    private val aid: ByteArray,
    initialMessage: NdefMessageSerializer,
    private val isWritable: Boolean = false,
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
        val res = try {
            val command = ApduCommand.fromBytes(rawCommand)
            val response = handleCommand(command)
            response.buffer
        } catch (_: IllegalArgumentException) {
            println("Aquisistooooooooooooooooooooooooooooooooooooooooooooooooooooooooooos");
            ApduResponse.error(ApduStatusWord.fromBytes(0x6F, 0x00, "SW (Unknown Error)")).buffer
        } catch (_: Exception) {
            ApduResponse.error(ApduStatusWord.fromBytes(0x6F, 0x00, "SW (Unknown Error)")).buffer
        }
        return res;
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
            val p = command.params.buffer
            if (p.contentEquals(ApduParams.byName.buffer)) {
                if (isNdefAid(command.data.buffer)) {
                    currentState = HceState.APP_SELECTED
                    return ApduResponse.success()
                } else {
                    return ApduResponse.error(ApduStatusWord.fileNotFound)
                }
            }
            return ApduResponse.error(ApduStatusWord.wrongP1P2)
        }
        return ApduResponse.error(ApduStatusWord.insNotSupported)
    }

    private fun handleAppSelectedState(command: ApduCommand): ApduResponse {
        if (command is SelectCommand) {
            val p = command.params.buffer
            if (!p.contentEquals(ApduParams.byFileId.buffer)) {
                return ApduResponse.error(ApduStatusWord.wrongP1P2)
            }
            val data = command.data.buffer
            if (data.size < 2) {
                return ApduResponse.error(ApduStatusWord.wrongLength)
            }
            val fileId = ((data[0].toInt() and 0xFF) shl 8) or (data[1].toInt() and 0xFF)
            return when (fileId) {
                0xE103 -> { currentState = HceState.CC_SELECTED; ApduResponse.success() }
                0xE104 -> { currentState = HceState.NDEF_SELECTED; ApduResponse.success() }
                else -> ApduResponse.error(ApduStatusWord.fileNotFound)
            }
        }
        return ApduResponse.error(ApduStatusWord.insNotSupported)
    }

    private fun handleCcSelectedState(command: ApduCommand): ApduResponse {
        return when (command) {
            is ReadBinaryCommand -> processRead(command, capabilityContainer.buffer)
            is SelectCommand -> handleAppSelectedState(command) // allow re-selecting files
            is UpdateBinaryCommand -> ApduResponse.error(ApduStatusWord.conditionsNotSatisfied)
            else -> ApduResponse.error(ApduStatusWord.insNotSupported)
        }
    }

    private fun handleNdefSelectedState(command: ApduCommand): ApduResponse {
        return when (command) {
            is ReadBinaryCommand -> processRead(command, ndefFile.buffer)
            is UpdateBinaryCommand -> processUpdate(command)
            is SelectCommand -> handleAppSelectedState(command) // allow switching between files
            else -> ApduResponse.error(ApduStatusWord.insNotSupported)
        }
    }

    private fun processRead(command: ReadBinaryCommand, file: Bytes): ApduResponse {
        val offset = command.offset
        if (offset >= file.size) {
            return ApduResponse.error(ApduStatusWord.wrongOffset)
        }
        val lengthToRead = if (command.lengthToRead == 0) 256 else command.lengthToRead
        if (lengthToRead > 256) {
            return ApduResponse.error(ApduStatusWord.wrongLength)
        }
        val bytesRemaining = file.size - offset
        val bytesToSend = min(lengthToRead, bytesRemaining)
        val chunk = file.sliceArray(offset until offset + bytesToSend)
        return ApduResponse.success(chunk)
    }

    private fun processUpdate(command: UpdateBinaryCommand): ApduResponse {
        // Check writability via CC flag propagated in construction; if not writable, reject
        // For simplicity, assume writability is determined externally via constructor flag
        // If not writable, 6985
        // We detect writability by attempting to begin or write; if design requires a flag, pass it through
        // Here we infer from ability to call write routines; if needed, you can store isWritable in the class
        // We'll add a guard using capabilityContainer contents isn't trivial here, so keep a constructor flag
        // For now, assume writable only if UpdateBinaryCommand is expected by caller; we'll enforce via field
        return try {
            // Infer writability from constructor parameter captured in closure
            if (!isWritable) return ApduResponse.error(ApduStatusWord.conditionsNotSatisfied)

            val offset = command.offset
            val data = command.dataToWrite

            if (offset == 0) {
                if (data.size != 2) return ApduResponse.error(ApduStatusWord.wrongLength)
                val nlen = ((data[0].toInt() and 0xFF) shl 8) or (data[1].toInt() and 0xFF)
                if (nlen == 0) {
                    ndefFile.beginWriteSession()
                    return ApduResponse.success()
                } else {
                    val ok = ndefFile.finalizeWrite(nlen)
                    return if (ok) ApduResponse.success() else ApduResponse.error(ApduStatusWord.wrongLength)
                }
            }
            if (offset == 1) {
                // Partial NLEN writes are not allowed
                return ApduResponse.error(ApduStatusWord.wrongP1P2)
            }
            // Data area write
            val ok = ndefFile.writeData(offset, data)
            return if (ok) ApduResponse.success() else ApduResponse.error(ApduStatusWord.conditionsNotSatisfied)
        } catch (_: Exception) {
            ApduResponse.error(ApduStatusWord.fromBytes(0x6F, 0x00, "SW (Unknown Error)"))
        }
    }

    private fun isNdefAid(aidToCheck: Bytes): Boolean {
        if (aidToCheck.size != aid.size) return false
        for (i in aidToCheck.indices) {
            if (aidToCheck[i] != aid[i]) return false
        }
        return true
    }
}
