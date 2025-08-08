package com.example.nfc_proof_of_concept

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.res.XmlResourceParser
import org.xmlpull.v1.XmlPullParser

class MainActivity: FlutterActivity() {
    private val CHANNEL = "nfc_aid_helper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
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
    }

    private fun getAidFromXml(): String? {
        try {
            val parser: XmlResourceParser = resources.getXml(R.xml.aid_list)
            
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
