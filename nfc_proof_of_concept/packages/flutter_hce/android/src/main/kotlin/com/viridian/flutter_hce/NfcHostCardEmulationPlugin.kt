package com.viridian.flutter_hce

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.nfc.NfcAdapter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import com.viridian.flutter_hce.app_layer.*
import com.viridian.flutter_hce.app_layer.ndef_format.fields.*
import com.viridian.flutter_hce.app_layer.ndef_format.serializers.*


class NfcHostCardEmulationPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var nfcAdapter: NfcAdapter? = null
    private var stateMachine: HceStateMachine? = null
    private var eventSink: EventSink? = null

    private val hceBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "io.flutter.plugins.nfc_host_card_emulation.TRANSACTION" -> {
                    val command = intent.getByteArrayExtra("command")
                    val response = intent.getByteArrayExtra("response")
                    val eventData = mapOf("command" to command, "response" to response)
                    
                    // Send to method channel (legacy support)
                    channel.invokeMethod("onHceTransaction", eventData)
                    
                    // Send to event stream
                    eventSink?.success(eventData)
                }
                "io.flutter.plugins.nfc_host_card_emulation.DEACTIVATED" -> {
                    val reason = intent.getIntExtra("reason", 0)
                    val eventData = mapOf("reason" to reason)
                    
                    // Send to method channel (legacy support)
                    channel.invokeMethod("onHceDeactivated", reason)
                    
                    // Send to event stream
                    eventSink?.success(eventData)
                }
            }
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "nfc_host_card_emulation")
        channel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "nfc_host_card_emulation_events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
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

    // StreamHandler implementation for EventChannel
    override fun onListen(arguments: Any?, events: EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "init" -> {
                    val recordsData = call.argument<List<Map<String, Any>>>("records")
                        ?: throw IllegalArgumentException("Records are required.")
                    val isWritable = call.argument<Boolean>("isWritable") ?: false
                    val maxNdefFileSize = call.argument<Int>("maxNdefFileSize") ?: 2048

                    // Create NDEF records from the provided data
                    val recordTuples = mutableListOf<NdefRecordTuple>()
                    
                    for (recordData in recordsData) {
                        val typeString = recordData["type"] as? String ?: "T"
                        val payloadData = recordData["payload"] as? ByteArray ?: ByteArray(0)
                        val idData = recordData["id"] as? ByteArray
                        
                        val recordTuple = NdefRecordTuple(
                            type = NdefTypeField.wellKnown(typeString),
                            payload = if (payloadData.isNotEmpty()) NdefPayload(payloadData) else null,
                            id = idData?.let { NdefIdField(it) }
                        )
                        recordTuples.add(recordTuple)
                    }
                    
                    val ndefMessage = NdefMessageSerializer.fromRecords(recordTuples)
                    stateMachine = HceStateMachine(ndefMessage, isWritable, maxNdefFileSize)
                    HceManager.stateMachine = stateMachine // Set in global manager for HCE service
                    result.success(true)
                }
                "checkNfcState" -> {
                    val nfcState = when {
                        nfcAdapter == null -> "not_supported"
                        !nfcAdapter!!.isEnabled -> "disabled"
                        else -> "enabled"
                    }
                    result.success(nfcState)
                }
                "getStateMachine" -> {
                    if (stateMachine == null) {
                        result.error("NOT_INITIALIZED", "HCE State Machine not initialized. Call init() first.", null)
                    } else {
                        result.success("State machine is initialized")
                    }
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("ERROR", "An error occurred: ${e.message}", e.toString())
        }
    }

    companion object {
        @JvmStatic
        fun getStateMachine(): HceStateMachine? {
            return null // This will need to be implemented with a proper singleton pattern
        }
    }
}