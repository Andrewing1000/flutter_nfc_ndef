package io.flutter.plugins.nfc_host_card_emulation.app_layer

import io.flutter.plugins.nfc_host_card_emulation.file_access.fields.ApduParams
import io.flutter.plugins.nfc_host_card_emulation.file_access.fields.ApduStatusWord
import io.flutter.plugins.nfc_host_card_emulation.file_access.serializers.*
import io.flutter.plugins.nfc_host_card_emulation.ndef_format.NdefMessageSerializer
import io.flutter.plugins.nfc_host_card_emulation.ndef_format.NdefRecordData
import java.lang.Integer.min

private enum class HceState {
    IDLE,
    NDEF_APP_SELECTED,
    FILE_SELECTED
}

private class NdefFile(
    message: NdefMessageSerializer,
    val maxFileSize: Int,
    val isWritable: Boolean
) {
    var buffer: Bytes
        private set

    init {
        buffer = Bytes(0)
        update(message)
    }

    fun update(message: NdefMessageSerializer) {
        val messageBytes = message.buffer
        val nlen = messageBytes.size
        require(nlen + 2 <= maxFileSize) { "NDEF message size ($nlen bytes) exceeds max file size ($maxFileSize bytes)." }
        val nlenBytes = Bytes(2)
        nlenBytes[0] = (nlen shr 8 and 0xFF).toByte()
        nlenBytes[1] = (nlen and 0xFF).toByte()
        buffer = nlenBytes + messageBytes
    }

    fun write(offset: Int, data: Bytes): Boolean {
        if (!isWritable) return false
        if (offset < 0 || offset + data.size > maxFileSize) return false

        val newSize = maxOf(buffer.size, offset + data.size)
        val newBuffer = buffer.copyOf(newSize)
        data.copyInto(newBuffer, offset)
        buffer = newBuffer
        return true
    }
}

class HceStateMachine(val aid: Bytes) {
    private var currentState: HceState = HceState.IDLE
    private var selectedFileId: Int? = null

    private var capabilityContainer: CapabilityContainer
    private val ndefFiles = mutableMapOf<Int, NdefFile>()
    private val fileDescriptors = mutableListOf<FileControlTlv>()

    companion object {
        const val CC_FILE_ID = 0xE103
        const val NDEF_FILE_ID = 0xE104
    }

    init {
        capabilityContainer = CapabilityContainer(fileDescriptors = emptyList())
        rebuildCapabilityContainer()
    }

    fun addOrUpdateNdefFile(
        fileId: Int,
        records: List<NdefRecordData>,
        maxFileSize: Int,
        isWritable: Boolean
    ) {
        require(fileId != CC_FILE_ID && fileId in 0x0000..0xFFFF) { "Invalid File ID: $fileId" }

        val message = NdefMessageSerializer.fromRecords(records)
        val file = NdefFile(
            message = message,
            maxFileSize = maxFileSize,
            isWritable = isWritable
        )
        ndefFiles[fileId] = file

        val tlv = if (fileId == NDEF_FILE_ID) {
            FileControlTlv.ndef(
                maxNdefFileSize = maxFileSize,
                isNdefWritable = isWritable
            )
        } else {
            FileControlTlv.proprietary(
                proprietaryFileId = fileId,
                maxProprietaryFileSize = maxFileSize,
                isProprietaryWritable = isWritable
            )
        }

        fileDescriptors.removeAll {
            val id = ((it.fileId.buffer[0].toInt() and 0xFF) shl 8) or (it.fileId.buffer[1].toInt() and 0xFF)
            id == fileId
        }
        fileDescriptors.add(tlv)
        rebuildCapabilityContainer()
    }

    fun deleteNdefFile(fileId: Int) {
        if (ndefFiles.containsKey(fileId)) {
            ndefFiles.remove(fileId)
            fileDescriptors.removeAll {
                val id = ((it.fileId.buffer[0].toInt() and 0xFF) shl 8) or (it.fileId.buffer[1].toInt() and 0xFF)
                id == fileId
            }
            rebuildCapabilityContainer()
        }
    }

    fun clearAllFiles() {
        ndefFiles.clear()
        fileDescriptors.clear()
        rebuildCapabilityContainer()
    }

    fun hasFile(fileId: Int): Boolean {
        return ndefFiles.containsKey(fileId)
    }

    fun onDeactivated() {
        currentState = HceState.IDLE
        selectedFileId = null
    }

    fun processCommand(rawCommand: Bytes): Bytes {
        return try {
            val command = ApduCommand.fromBytes(rawCommand)
            if (command.cla != ApduClass.standard) {
                return ApduResponse.error(ApduStatusWord.claNotSupported).buffer
            }
            handleCommand(command).buffer
        } catch (e: Exception) {
            println("HCE FSM Error: ${e.message}")
            ApduResponse.error(ApduStatusWord.conditionsNotSatisfied).buffer
        }
    }

    private fun rebuildCapabilityContainer() {
        capabilityContainer = CapabilityContainer(fileDescriptors = fileDescriptors)
    }

    private fun handleCommand(command: ApduCommand): ApduResponse {
        return when (currentState) {
            HceState.IDLE -> handleIdleState(command)
            HceState.NDEF_APP_SELECTED -> handleNdefAppSelectedState(command)
            HceState.FILE_SELECTED -> handleFileSelectedState(command)
        }
    }

    private fun handleIdleState(command: ApduCommand): ApduResponse {
        if (command is SelectCommand && command.data.buffer.contentEquals(this.aid)) {
            currentState = HceState.NDEF_APP_SELECTED
            selectedFileId = null
            return ApduResponse.success()
        }
        return ApduResponse.error(ApduStatusWord.conditionsNotSatisfied)
    }

    private fun handleNdefAppSelectedState(command: ApduCommand): ApduResponse {
        if (command is SelectCommand) {
            val fileId = ((command.data.buffer[0].toInt() and 0xFF) shl 8) or (command.data.buffer[1].toInt() and 0xFF)
            if (fileId == CC_FILE_ID) {
                currentState = HceState.FILE_SELECTED
                selectedFileId = fileId
                return ApduResponse.success()
            }
            if (ndefFiles.containsKey(fileId)) {
                currentState = HceState.FILE_SELECTED
                selectedFileId = fileId
                return ApduResponse.success()
            }
            return ApduResponse.error(ApduStatusWord.fileNotFound)
        }
        return ApduResponse.error(ApduStatusWord.insNotSupported)
    }

    private fun handleFileSelectedState(command: ApduCommand): ApduResponse {
        if (command is SelectCommand) {
            currentState = HceState.NDEF_APP_SELECTED
            selectedFileId = null
            return handleNdefAppSelectedState(command)
        }

        val currentFileId = selectedFileId ?: return ApduResponse.error(ApduStatusWord.conditionsNotSatisfied)

        return when (command) {
            is ReadBinaryCommand -> processRead(command, currentFileId)
            is UpdateBinaryCommand -> processUpdate(command, currentFileId)
            else -> ApduResponse.error(ApduStatusWord.insNotSupported)
        }
    }

    private fun getFileBuffer(fileId: Int): Bytes? {
        return when (fileId) {
            CC_FILE_ID -> capabilityContainer.buffer
            else -> ndefFiles[fileId]?.buffer
        }
    }

    private fun processRead(command: ReadBinaryCommand, fileId: Int): ApduResponse {
        val fileBuffer = getFileBuffer(fileId) ?: return ApduResponse.error(ApduStatusWord.fileNotFound)
        val offset = command.offset
        if (offset < 0 || offset > fileBuffer.size) {
            return ApduResponse.error(ApduStatusWord.wrongOffset)
        }
        if (offset == fileBuffer.size) {
             return ApduResponse.success(Bytes(0))
        }

        val lengthToRead = if (command.lengthToRead == 0) 256 else command.lengthToRead
        val bytesRemaining = fileBuffer.size - offset
        val bytesToSend = min(lengthToRead, bytesRemaining)

        val chunk = fileBuffer.sliceArray(offset until offset + bytesToSend)
        return ApduResponse.success(chunk)
    }

    private fun processUpdate(command: UpdateBinaryCommand, fileId: Int): ApduResponse {
        if (fileId == CC_FILE_ID) {
            return ApduResponse.error(ApduStatusWord.conditionsNotSatisfied)
        }

        val ndefFile = ndefFiles[fileId] ?: return ApduResponse.error(ApduStatusWord.fileNotFound)
        if (!ndefFile.isWritable) {
            return ApduResponse.error(ApduStatusWord.conditionsNotSatisfied)
        }

        val offset = command.offset
        val dataToWrite = command.dataToWrite
        if (offset < 0 || offset > ndefFile.maxFileSize) {
            return ApduResponse.error(ApduStatusWord.wrongOffset)
        }
        if (offset + dataToWrite.size > ndefFile.maxFileSize) {
            return ApduResponse.error(ApduStatusWord.wrongLength)
        }

        ndefFile.write(offset, dataToWrite)
        return ApduResponse.success()
    }
}