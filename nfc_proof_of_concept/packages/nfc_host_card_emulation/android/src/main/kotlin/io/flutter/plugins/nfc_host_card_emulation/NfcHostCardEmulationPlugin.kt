package io.flutter.plugins.nfc_host_card_emulation

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.nfc.NfcAdapter
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugins.nfc_host_card_emulation.app_layer.HceStateMachine
import io.flutter.plugins.nfc_host_card_emulation.ndef_format.NdefRecordData
import io.flutter.plugins.nfc_host_card_emulation.ndef_format.fields.NdefPayload
import io.flutter.plugins.nfc_host_card_emulation.ndef_format.fields.NdefTypeField

class NfcHostCardEmulationPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var nfcAdapter: NfcAdapter? = null

    private val hceBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "io.flutter.plugins.nfc_host_card_emulation.TRANSACTION" -> {
                    val command = intent.getByteArrayExtra("command")
                    val response = intent.getByteArrayExtra("response")
                    val eventData = mapOf("command" to command, "response" to response)
                    channel.invokeMethod("onHceTransaction", eventData)
                }
                "io.flutter.plugins.nfc_host_card_emulation.DEACTIVATED" -> {
                    val reason = intent.getIntExtra("reason", 0)
                    channel.invokeMethod("onHceDeactivated", reason)
                }
            }
        }
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "nfc_host_card_emulation")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
        val intentFilter = IntentFilter().apply {
            addAction("io.flutter.plugins.nfc_host_card_emulation.TRANSACTION")
            addAction("io.flutter.plugins.nfc_host_card_emulation.DEACTIVATED")
        }
        activity?.registerReceiver(hceBroadcastReceiver, intentFilter)
    }

    override fun onDetachedFromActivity() {
        activity?.unregisterReceiver(hceBroadcastReceiver)
        activity = null
        nfcAdapter = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { onAttachedToActivity(binding) }
    override fun onDetachedFromActivityForConfigChanges() { onDetachedFromActivity() }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        val machine = HceManager.stateMachine

        fun requireInitialized(block: (HceStateMachine) -> Unit) {
            if (machine == null) {
                result.error("NOT_INITIALIZED", "HCE State Machine not initialized. Call init() first.", null)
                return
            }
            try {
                block(machine)
            } catch (e: HceError) {
                val (code, message) = e.toMethodChannelError()
                result.error(code, message, e.stackTraceToString())
            } catch (e: Exception) {
                result.error("UNKNOWN_ERROR", "An unexpected error occurred: ${e.message}", e.stackTraceToString())
            }
        }

        when (call.method) {
            "init" -> {
                try {
                    val aid = call.argument<ByteArray>("aid") 
                        ?: throw InvalidAidError("AID is required.")
                    
                    ValidationUtils.validateAid(aid)
                    HceManager.stateMachine = HceStateMachine(aid)
                    result.success(true)
                } catch (e: HceError) {
                    val (code, message) = e.toMethodChannelError()
                    result.error(code, message, e.stackTraceToString())
                } catch (e: Exception) {
                    result.error("INIT_FAILED", "Failed to initialize HCE: ${e.message}", e.stackTraceToString())
                }
            }
            "addOrUpdateFile" -> requireInitialized {
                val fileId = call.argument<Int>("fileId")
                    ?: throw InvalidFileIdError("File ID is required.")
                val recordsList = call.argument<List<Map<String, Any>>>("records")
                    ?: throw InvalidNdefFormatError("Records list is required.")
                val maxFileSize = call.argument<Int>("maxFileSize")
                    ?: throw InvalidStateError("Max file size is required.")
                val isWritable = call.argument<Boolean>("isWritable")
                    ?: throw InvalidStateError("isWritable flag is required.")

                ValidationUtils.validateFileId(fileId)
                ValidationUtils.validateNdefMessageSize(maxFileSize)
                ValidationUtils.validateRecordTypes(recordsList)

                val recordData = recordsList.map {
                    NdefRecordData(
                        type = NdefTypeField.wellKnown((it["type"] as String)),
                        payload = NdefPayload((it["payload"] as ByteArray)),
                        id = null
                    )
                }
                it.addOrUpdateNdefFile(fileId, recordData, maxFileSize, isWritable)
                result.success(true)
            }
            "deleteFile" -> requireInitialized {
                val fileId = call.argument<Int>("fileId")
                    ?: throw InvalidFileIdError("File ID is required.")
                
                ValidationUtils.validateFileId(fileId)
                
                if (!it.hasFile(fileId)) {
                    throw FileNotFoundError("File 0x${fileId.toString(16)} does not exist")
                }
                
                it.deleteNdefFile(fileId)
                result.success(true)
            }
            "clearAllFiles" -> requireInitialized {
                it.clearAllFiles()
                result.success(true)
            }
            "hasFile" -> requireInitialized {
                val fileId = call.argument<Int>("fileId")
                    ?: throw InvalidFileIdError("File ID is required.")
                
                ValidationUtils.validateFileId(fileId)
                result.success(it.hasFile(fileId))
            }
            "checkNfcState" -> {
                val nfcState = when {
                    nfcAdapter == null -> "not_supported"
                    !nfcAdapter!!.isEnabled -> "disabled"
                    else -> "enabled"
                }
                result.success(nfcState)
            }
            else -> result.notImplemented()
        }
    }
}