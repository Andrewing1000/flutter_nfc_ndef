package com.viridian.flutter_hce

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.nfc.NfcAdapter
import android.util.Log
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

class FlutterHcePlugin : FlutterPlugin, MethodCallHandler, ActivityAware, StreamHandler {
    
    // ===== CHANNELS Y COMUNICACIÓN =====
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventSink? = null
    
    private var activity: Activity? = null
    private var nfcAdapter: NfcAdapter? = null
    private var stateMachine: HceStateMachine? = null

    companion object{
        const val TAG = "FlutterHcePlugin";
    }

    private val hceBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "io.flutter.plugins.nfc_host_card_emulation.TRANSACTION" -> {
                    val command = intent.getByteArrayExtra("command")
                    val response = intent.getByteArrayExtra("response")
                    val eventData = mapOf(
                        "type" to "transaction",
                        "command" to command?.toList(),
                        "response" to response?.toList()
                    )
                    
                    Log.d(TAG, "HCE Transaction received")
                    
                    // Enviar a Flutter via EventChannel
                    eventSink?.success(eventData)
                }
                
                "io.flutter.plugins.nfc_host_card_emulation.DEACTIVATED" -> {
                    val reason = intent.getIntExtra("reason", 0)
                    val eventData = mapOf(
                        "type" to "deactivated",
                        "reason" to reason
                    )
                    
                    Log.d(TAG, "HCE Deactivated: reason $reason")
                    
                    // Enviar a Flutter
                    eventSink?.success(eventData)
                }
            }
        }
    }


    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "Plugin attached to engine")
        
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "nfc_host_card_emulation")
        channel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "nfc_host_card_emulation_events")
        eventChannel.setStreamHandler(this)
        
        Log.d(TAG, "Channels configured: MethodChannel and EventChannel ready")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "Plugin detached from engine")
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    // ===== ACTIVITY LIFECYCLE =====

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "Plugin attached to activity")
        
        activity = binding.activity
        nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
        
        val intentFilter = IntentFilter().apply {
            addAction("io.flutter.plugins.nfc_host_card_emulation.TRANSACTION")
            addAction("io.flutter.plugins.nfc_host_card_emulation.DEACTIVATED")
        }
        activity?.registerReceiver(hceBroadcastReceiver, intentFilter)
        
        Log.d(TAG, "Activity setup complete - NFC: ${nfcAdapter?.isEnabled}")
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "Plugin detached from activity")
        
        try {
            activity?.unregisterReceiver(hceBroadcastReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "Error unregistering receiver: ${e.message}")
        }
        
        activity = null
        nfcAdapter = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { 
        onAttachedToActivity(binding) 
    }
    
    override fun onDetachedFromActivityForConfigChanges() { 
        onDetachedFromActivity() 
    }

    // ===== EVENTCHANNEL STREAMHANDLER =====

    override fun onListen(arguments: Any?, events: EventSink?) {
        Log.d(TAG, "EventChannel listener attached")
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "EventChannel listener cancelled")
        eventSink = null
    }

    // ===== METHODCHANNEL HANDLER =====

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "Method call: ${call.method}")
        
        try {
            when (call.method) {
                "init" -> initializeHce(call, result)
                "checkNfcState" -> checkNfcState(result)
                "getStateMachine" -> getStateMachineStatus(result)
                else -> {
                    Log.w(TAG, "Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in method ${call.method}: ${e.message}", e)
            result.error("ERROR", "Error en ${call.method}: ${e.message}", e.toString())
        }
    }

    private fun initializeHce(call: MethodCall, result: Result) {
        val aid = call.argument<ByteArray>("aid")
            ?: throw IllegalArgumentException("AID es requerido")
        val recordsData = call.argument<List<Map<String, Any>>>("records")
            ?: throw IllegalArgumentException("Records son requeridos")
        val isWritable = call.argument<Boolean>("isWritable") ?: false
        val maxNdefFileSize = call.argument<Int>("maxNdefFileSize") ?: 2048

        // Validar AID
        if (aid.size < 5 || aid.size > 16) {
            throw IllegalArgumentException("AID debe tener entre 5 y 16 bytes")
        }

        Log.d(TAG, "Initializing HCE with AID: ${aid.joinToString { "%02X".format(it) }}")

        val simpleRecords = mutableListOf<NdefRecordTuple>()
        
        if (recordsData.isNotEmpty()) {
            val firstRecord = recordsData[0]
            val typeString = firstRecord["type"] as? String ?: "T"
            val payloadData = firstRecord["payload"] as? ByteArray ?: ByteArray(0)
            
            val recordTuple = NdefRecordTuple(
                type = NdefTypeField.wellKnown(typeString),
                payload = if (payloadData.isNotEmpty()) NdefPayload(payloadData) else null,
                id = null 
            )
            simpleRecords.add(recordTuple)
            
            Log.d(TAG, "Added NDEF record: type=$typeString, payload=${payloadData.size} bytes")
        }

        val ndefMessage = NdefMessageSerializer.fromRecords(simpleRecords)
        
    stateMachine = HceStateMachine(aid, ndefMessage, isWritable, maxNdefFileSize)
    HceManager.stateMachine = stateMachine
        
        Log.d(TAG, "HCE initialized successfully")
        result.success(true)
    }

    private fun checkNfcState(result: Result) {
        val nfcState = when {
            nfcAdapter == null -> "not_supported"
            !nfcAdapter!!.isEnabled -> "disabled"
            else -> "enabled"
        }
        
        Log.d(TAG, "NFC State: $nfcState")
        result.success(nfcState)
    }

    private fun getStateMachineStatus(result: Result) {
        if (stateMachine == null) {
            result.error("NOT_INITIALIZED", "State Machine no inicializado. Llama init() primero.", null)
        } else {
            result.success("State machine initialized")
        }
    }
}
