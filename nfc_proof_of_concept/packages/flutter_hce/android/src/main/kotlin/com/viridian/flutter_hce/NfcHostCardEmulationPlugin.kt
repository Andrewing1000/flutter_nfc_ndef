package com.viridian.flutter_hce

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.nfc.NfcAdapter
import android.nfc.Tag
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
import io.flutter.plugin.common.PluginRegistry.NewIntentListener
import com.viridian.flutter_hce.app_layer.*
import com.viridian.flutter_hce.app_layer.ndef_format.fields.*
import com.viridian.flutter_hce.app_layer.ndef_format.serializers.*

class NfcHostCardEmulationPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, StreamHandler, NewIntentListener {
    
    // ===== CHANNELS Y COMUNICACIÓN =====
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var intentEventChannel: EventChannel
    private var eventSink: EventSink? = null
    private var intentEventSink: EventSink? = null
    
    private var activity: Activity? = null
    private var nfcAdapter: NfcAdapter? = null
    private var stateMachine: HceStateMachine? = null
    
    private var cachedNfcIntent: Intent? = null

    
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
        
        setInstance(this)
        
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "nfc_host_card_emulation")
        channel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "nfc_host_card_emulation_events")
        eventChannel.setStreamHandler(this)
        
        intentEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "nfc_intent_events")
        intentEventChannel.setStreamHandler(object : StreamHandler {
            override fun onListen(arguments: Any?, events: EventSink?) {
                intentEventSink = events
                Log.d(TAG, "Intent EventChannel listener attached")
            }
            
            override fun onCancel(arguments: Any?) {
                intentEventSink = null
                Log.d(TAG, "Intent EventChannel listener cancelled")
            }
        })
        
        Log.d(TAG, "Channels configured: MethodChannel and 2 EventChannels ready")
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
        

        binding.addOnNewIntentListener(this)
        
        val intentFilter = IntentFilter().apply {
            addAction("io.flutter.plugins.nfc_host_card_emulation.TRANSACTION")
            addAction("io.flutter.plugins.nfc_host_card_emulation.DEACTIVATED")
        }
        activity?.registerReceiver(hceBroadcastReceiver, intentFilter)
        
        handleNfcIntent(activity?.intent)
        
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

    // ===== NFC INTENT LAUNCHING =====

    override fun onNewIntent(intent: Intent): Boolean {
        Log.d(TAG, "onNewIntent: ${intent.action}")
        return handleNfcIntent(intent)
    }

    private fun handleNfcIntent(intent: Intent?): Boolean {
        if (intent == null) return false
        
        Log.d(TAG, "Handling intent: ${intent.action}")
        
        when (intent.action) {
            NfcAdapter.ACTION_TECH_DISCOVERED,
            NfcAdapter.ACTION_NDEF_DISCOVERED -> {
                Log.d(TAG, "NFC intent detected - app launched/resumed via HCE")
                
                val nfcData = extractNfcData(intent)
                
                cachedNfcIntent = intent
                
                val eventData = mapOf(
                    "type" to "nfc_intent",
                    "action" to intent.action,
                    "data" to nfcData
                )
                
                intentEventSink?.success(eventData)
                
                return true
            }
        }

        if (intent.getBooleanExtra("launched_via_hce", false)) {
            Log.d(TAG, "HCE auto-launch intent detected (non-NFC action): ${intent.action}")
            val data = extractNfcData(intent)

            cachedNfcIntent = intent

            val eventData = mapOf(
                "type" to "hce_launch",
                "action" to (intent.action ?: ""),
                "data" to data
            )

            intentEventSink?.success(eventData)

            return true
        }
        return false
    }

    private fun extractNfcData(intent: Intent): Map<String, Any> {
        val data = mutableMapOf<String, Any>()
        
        // Obtener tag NFC
        val tag = intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)
        if (tag != null) {
            data["tagId"] = tag.id.toList()
            data["techList"] = tag.techList.toList()
            
            Log.d(TAG, "NFC Tag ID: ${tag.id.joinToString { "%02X".format(it) }}")
            Log.d(TAG, "Tech List: ${tag.techList.joinToString()}")
        }
        
        // Obtener extras del intent
        val extras = mutableMapOf<String, Any>()
        intent.extras?.let { bundle ->
            bundle.keySet().forEach { key ->
                bundle.get(key)?.let { value ->
                    when (value) {
                        is String -> extras[key] = value
                        is ByteArray -> extras[key] = value.toList()
                        is Int -> extras[key] = value
                        is Boolean -> extras[key] = value
                        else -> extras[key] = value.toString()
                    }
                }
            }
        }
        if (intent.hasExtra("launched_via_hce")) {
            extras["launched_via_hce"] = intent.getBooleanExtra("launched_via_hce", false)
            extras["hce_event"] = intent.getStringExtra("hce_event") ?: ""
        }
        data["extras"] = extras
        
        return data
    }

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
                "getNfcIntent" -> getNfcIntentData(result)
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
        
        Log.d(TAG, "✅ HCE initialized successfully")
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

    private fun getNfcIntentData(result: Result) {
        if (cachedNfcIntent != null) {
            val nfcData = extractNfcData(cachedNfcIntent!!)
            val intentData = mapOf(
                "action" to cachedNfcIntent!!.action,
                "data" to nfcData
            )
            
            Log.d(TAG, "Returning cached NFC intent data")
            result.success(intentData)
            
            cachedNfcIntent = null
        } else {
            Log.d(TAG, "No cached NFC intent data")
            result.success(null)
        }
    }

    // ===== SINGLETON Y ACCESO ESTÁTICO =====

    companion object {
        private const val TAG = "NfcHostCardEmulation"
        private var instance: NfcHostCardEmulationPlugin? = null
        
        @JvmStatic
        fun getStateMachine(): HceStateMachine? {
            return instance?.stateMachine
        }
        
        internal fun setInstance(plugin: NfcHostCardEmulationPlugin) {
            instance = plugin
        }
    }
}
