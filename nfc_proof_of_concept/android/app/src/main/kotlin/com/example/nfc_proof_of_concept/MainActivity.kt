package com.example.nfc_proof_of_concept

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.res.XmlResourceParser
import android.content.Intent
import android.nfc.NfcAdapter
import android.os.Bundle
import org.xmlpull.v1.XmlPullParser

class MainActivity: FlutterActivity() {
    private val CHANNEL = "nfc_aid_helper"
    private val LAUNCH_CHANNEL = "app_launch_info"
    private var launchedFromTechDiscovered = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if launched from TECH_DISCOVERED
        checkLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkLaunchIntent(intent)
        
        // Notify Flutter about new intent
        if (launchedFromTechDiscovered) {
            notifyFlutterAboutTechDiscovered()
        }
    }

    private fun checkLaunchIntent(intent: Intent?) {
        launchedFromTechDiscovered = intent?.action == NfcAdapter.ACTION_TECH_DISCOVERED
    }

    private fun notifyFlutterAboutTechDiscovered() {
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, LAUNCH_CHANNEL).invokeMethod("techDiscovered", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Original AID helper channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAidFromXml" -> {
                    try {
                        val aid = getAidFromXml()
                        result.success(aid)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to retrieve AID: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Launch info channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchInfo" -> {
                    val launchInfo = mapOf("launchedFromTechDiscovered" to launchedFromTechDiscovered)
                    result.success(launchInfo)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getAidFromXml(): String? {
        try {
            val parser: XmlResourceParser = resources.getXml(R.xml.apduservice)
            
            var eventType = parser.eventType
            while (eventType != XmlPullParser.END_DOCUMENT) {
                when (eventType) {
                    XmlPullParser.START_TAG -> {
                        if (parser.name == "aid-filter") {
                            val aidValue = parser.getAttributeValue("http://schemas.android.com/apk/res/android", "name")
                            if (aidValue != null) {
                                parser.close()
                                return aidValue
                            }
                        }
                    }
                }
                eventType = parser.next()
            }
            parser.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }
}
