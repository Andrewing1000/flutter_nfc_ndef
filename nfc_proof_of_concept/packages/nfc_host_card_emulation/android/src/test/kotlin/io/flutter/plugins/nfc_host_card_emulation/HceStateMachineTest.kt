package io.flutter.plugins.nfc_host_card_emulation

import io.flutter.plugins.nfc_host_card_emulation.app_layer.HceError
import io.flutter.plugins.nfc_host_card_emulation.app_layer.HceStateMachine
import io.flutter.plugins.nfc_host_card_emulation.app_layer.InvalidAidError
import io.flutter.plugins.nfc_host_card_emulation.app_layer.InvalidFileIdError
import io.flutter.plugins.nfc_host_card_emulation.app_layer.InvalidNdefFormatError
import io.flutter.plugins.nfc_host_card_emulation.file_access.fields.ApduStatusWord
import io.flutter.plugins.nfc_host_card_emulation.file_access.serializers.ApduCommand
import io.flutter.plugins.nfc_host_card_emulation.ndef_format.NdefRecordData
import io.flutter.plugins.nfc_host_card_emulation.ndef_format.fields.NdefPayload
import io.flutter.plugins.nfc_host_card_emulation.ndef_format.fields.NdefTypeField
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

class HceStateMachineTest {
    private lateinit var stateMachine: HceStateMachine
    private val validAid = byteArrayOf(0xD2.toByte(), 0x76.toByte(), 0x00.toByte(), 0x00.toByte(), 0x85.toByte(), 0x01.toByte(), 0x01.toByte())
    
    @Before
    fun setUp() {
        stateMachine = HceStateMachine(validAid)
    }

    @Test
    fun `initializes with valid AID`() {
        assertNotNull(stateMachine)
        assertArrayEquals(validAid, stateMachine.aid)
    }

    @Test(expected = InvalidAidError::class)
    fun `fails initialization with invalid AID`() {
        HceStateMachine(byteArrayOf(0x01.toByte(), 0x02.toByte()))
    }

    @Test
    fun `adds NDEF file with valid data`() {
        val fileId = 0xE104
        val records = listOf(
            NdefRecordData(
                type = NdefTypeField.wellKnown("T"),
                payload = NdefPayload("Hello".toByteArray())
            )
        )

        stateMachine.addOrUpdateNdefFile(fileId, records, 2048, false)
        assertTrue(stateMachine.hasFile(fileId))
    }

    @Test(expected = InvalidFileIdError::class)
    fun `fails to add file with invalid ID`() {
        val records = listOf(
            NdefRecordData(
                type = NdefTypeField.wellKnown("T"),
                payload = NdefPayload("Hello".toByteArray())
            )
        )
        stateMachine.addOrUpdateNdefFile(0x3F00, records, 2048, false)
    }

    @Test
    fun `updates existing file`() {
        val fileId = 0xE104
        val records1 = listOf(
            NdefRecordData(
                type = NdefTypeField.wellKnown("T"),
                payload = NdefPayload("Hi".toByteArray())
            )
        )
        val records2 = listOf(
            NdefRecordData(
                type = NdefTypeField.wellKnown("T"),
                payload = NdefPayload("Bye".toByteArray())
            )
        )

        stateMachine.addOrUpdateNdefFile(fileId, records1, 2048, false)
        stateMachine.addOrUpdateNdefFile(fileId, records2, 2048, false)
        assertTrue(stateMachine.hasFile(fileId))
    }

    @Test
    fun `handles SELECT commands correctly`() {
        // SELECT NDEF application
        val selectAppCommand = ApduCommand.select(validAid)
        var response = stateMachine.processCommand(selectAppCommand.buffer)
        assertEquals(ApduStatusWord.success, ApduStatusWord.fromBytes(response))

        // SELECT CC file
        val selectCcCommand = ApduCommand.selectById(0xE103)
        response = stateMachine.processCommand(selectCcCommand.buffer)
        assertEquals(ApduStatusWord.success, ApduStatusWord.fromBytes(response))
    }

    @Test
    fun `handles concurrent access safely`() {
        val threadCount = 10
        val executor = Executors.newFixedThreadPool(threadCount)
        val latch = CountDownLatch(threadCount)
        val errors = mutableListOf<Throwable>()

        repeat(threadCount) { threadId ->
            executor.submit {
                try {
                    val fileId = 0xE104 + threadId
                    val records = listOf(
                        NdefRecordData(
                            type = NdefTypeField.wellKnown("T"),
                            payload = NdefPayload("Thread $threadId".toByteArray())
                        )
                    )
                    stateMachine.addOrUpdateNdefFile(fileId, records, 2048, false)
                    assertTrue(stateMachine.hasFile(fileId))
                } catch (e: Throwable) {
                    synchronized(errors) {
                        errors.add(e)
                    }
                } finally {
                    latch.countDown()
                }
            }
        }

        assertTrue(latch.await(5, TimeUnit.SECONDS))
        assertTrue("Concurrent access errors: ${errors.joinToString()}", errors.isEmpty())
    }

    @Test
    fun `handles state transitions correctly`() {
        // Initial state
        val selectAppCommand = ApduCommand.select(validAid)
        var response = stateMachine.processCommand(selectAppCommand.buffer)
        assertEquals(ApduStatusWord.success, ApduStatusWord.fromBytes(response))

        // Select CC file
        val selectCcCommand = ApduCommand.selectById(0xE103)
        response = stateMachine.processCommand(selectCcCommand.buffer)
        assertEquals(ApduStatusWord.success, ApduStatusWord.fromBytes(response))

        // Try to read CC
        val readCcCommand = ApduCommand.readBinary(0, 15)
        response = stateMachine.processCommand(readCcCommand.buffer)
        assertEquals(ApduStatusWord.success, ApduStatusWord.fromBytes(response))

        // Deactivate and try to read (should fail)
        stateMachine.onDeactivated()
        response = stateMachine.processCommand(readCcCommand.buffer)
        assertEquals(ApduStatusWord.conditionsNotSatisfied, ApduStatusWord.fromBytes(response))
    }

    @Test
    fun `validates NDEF message size`() {
        val fileId = 0xE104
        val oversizedPayload = ByteArray(70000) // Exceeds typical max size
        val records = listOf(
            NdefRecordData(
                type = NdefTypeField.wellKnown("T"),
                payload = NdefPayload(oversizedPayload)
            )
        )

        var exception: HceError? = null
        try {
            stateMachine.addOrUpdateNdefFile(fileId, records, 2048, false)
        } catch (e: HceError) {
            exception = e
        }

        assertNotNull(exception)
        assertTrue(exception is InvalidNdefFormatError)
    }

    @Test
    fun `handles READ BINARY commands correctly`() {
        // First add a file
        val fileId = 0xE104
        val testData = "Hello, NFC reader!"
        val records = listOf(
            NdefRecordData(
                type = NdefTypeField.wellKnown("T"),
                payload = NdefPayload(testData.toByteArray())
            )
        )
        stateMachine.addOrUpdateNdefFile(fileId, records, 2048, false)

        // Select the application and file
        stateMachine.processCommand(ApduCommand.select(validAid).buffer)
        stateMachine.processCommand(ApduCommand.selectById(fileId).buffer)

        // Try to read in chunks
        val readCommand1 = ApduCommand.readBinary(0, 10)
        val response1 = stateMachine.processCommand(readCommand1.buffer)
        assertEquals(ApduStatusWord.success, ApduStatusWord.fromBytes(response1))

        val readCommand2 = ApduCommand.readBinary(10, 10)
        val response2 = stateMachine.processCommand(readCommand2.buffer)
        assertEquals(ApduStatusWord.success, ApduStatusWord.fromBytes(response2))
    }
}
