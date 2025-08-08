package io.flutter.plugins.nfc_host_card_emulation

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE)
class NfcHostCardEmulationPluginTest {
    private lateinit var plugin: NfcHostCardEmulationPlugin
    private lateinit var channel: MethodChannel
    private val result: MethodChannel.Result = mockk(relaxed = true)

    @Before
    fun setUp() {
        channel = mockk(relaxed = true)
        plugin = NfcHostCardEmulationPlugin()
        plugin.onAttachedToEngine(mockk {
            every { binaryMessenger } returns mockk()
        })
    }

    @Test
    fun `init with valid AID succeeds`() {
        val aid = byteArrayOf(0xD2.toByte(), 0x76.toByte(), 0x00.toByte(), 0x00.toByte(), 0x85.toByte(), 0x01.toByte(), 0x01.toByte())
        val call = MethodCall("init", mapOf("aid" to aid))
        
        plugin.onMethodCall(call, result)
        
        verify { result.success(true) }
    }

    @Test
    fun `init with invalid AID fails`() {
        val aid = byteArrayOf(0x01.toByte(), 0x02.toByte())
        val call = MethodCall("init", mapOf("aid" to aid))
        
        plugin.onMethodCall(call, result)
        
        verify { result.error("INVALID_AID", any(), any()) }
    }

    @Test
    fun `addOrUpdateFile with valid data succeeds`() {
        // First initialize
        val aid = byteArrayOf(0xD2.toByte(), 0x76.toByte(), 0x00.toByte(), 0x00.toByte(), 0x85.toByte(), 0x01.toByte(), 0x01.toByte())
        plugin.onMethodCall(MethodCall("init", mapOf("aid" to aid)), result)

        val records = listOf(
            mapOf(
                "type" to "T",
                "payload" to "Hello".toByteArray()
            )
        )
        
        val call = MethodCall("addOrUpdateFile", mapOf(
            "fileId" to 0xE104,
            "records" to records,
            "maxFileSize" to 2048,
            "isWritable" to false
        ))
        
        plugin.onMethodCall(call, result)
        
        verify { result.success(true) }
    }

    @Test
    fun `addOrUpdateFile without init fails`() {
        val records = listOf(
            mapOf(
                "type" to "T",
                "payload" to "Hello".toByteArray()
            )
        )
        
        val call = MethodCall("addOrUpdateFile", mapOf(
            "fileId" to 0xE104,
            "records" to records,
            "maxFileSize" to 2048,
            "isWritable" to false
        ))
        
        plugin.onMethodCall(call, result)
        
        verify { result.error("NOT_INITIALIZED", any(), any()) }
    }

    @Test
    fun `deleteFile with valid ID succeeds`() {
        // First initialize and add a file
        val aid = byteArrayOf(0xD2.toByte(), 0x76.toByte(), 0x00.toByte(), 0x00.toByte(), 0x85.toByte(), 0x01.toByte(), 0x01.toByte())
        plugin.onMethodCall(MethodCall("init", mapOf("aid" to aid)), result)

        val records = listOf(
            mapOf(
                "type" to "T",
                "payload" to "Hello".toByteArray()
            )
        )
        
        plugin.onMethodCall(MethodCall("addOrUpdateFile", mapOf(
            "fileId" to 0xE104,
            "records" to records,
            "maxFileSize" to 2048,
            "isWritable" to false
        )), result)

        val call = MethodCall("deleteFile", mapOf("fileId" to 0xE104))
        plugin.onMethodCall(call, result)
        
        verify { result.success(true) }
    }

    @Test
    fun `clearAllFiles succeeds`() {
        // First initialize
        val aid = byteArrayOf(0xD2.toByte(), 0x76.toByte(), 0x00.toByte(), 0x00.toByte(), 0x85.toByte(), 0x01.toByte(), 0x01.toByte())
        plugin.onMethodCall(MethodCall("init", mapOf("aid" to aid)), result)

        val call = MethodCall("clearAllFiles", null)
        plugin.onMethodCall(call, result)
        
        verify { result.success(true) }
    }

    @Test
    fun `hasFile returns correct state`() {
        // First initialize
        val aid = byteArrayOf(0xD2.toByte(), 0x76.toByte(), 0x00.toByte(), 0x00.toByte(), 0x85.toByte(), 0x01.toByte(), 0x01.toByte())
        plugin.onMethodCall(MethodCall("init", mapOf("aid" to aid)), result)

        // Check non-existent file
        plugin.onMethodCall(MethodCall("hasFile", mapOf("fileId" to 0xE104)), result)
        verify { result.success(false) }

        // Add file
        val records = listOf(
            mapOf(
                "type" to "T",
                "payload" to "Hello".toByteArray()
            )
        )
        
        plugin.onMethodCall(MethodCall("addOrUpdateFile", mapOf(
            "fileId" to 0xE104,
            "records" to records,
            "maxFileSize" to 2048,
            "isWritable" to false
        )), result)

        // Check existing file
        plugin.onMethodCall(MethodCall("hasFile", mapOf("fileId" to 0xE104)), result)
        verify { result.success(true) }
    }

    @Test
    fun `checkNfcState returns correct state`() {
        val call = MethodCall("checkNfcState", null)
        plugin.onMethodCall(call, result)
        
        verify { result.success(any<String>()) }
    }
}
