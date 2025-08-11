package com.viridian.flutter_hce

import android.content.Intent
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log
import android.content.pm.PackageManager

class AndroidHceService : HostApduService() {

    private val conditionsNotSatisfiedResponse = byteArrayOf(0x69, 0x85.toByte())
    private val failureResponse = byteArrayOf(0x6F, 0x00)

    private fun ByteArray.toHex(): String = joinToString(" ") { "%02X".format(it) }

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null) {
            return failureResponse
        }

        Log.d("HCE_SERVICE", "--> Command: ${commandApdu.toHex()}")

        val stateMachine = HceManager.stateMachine

        // Si aún no hay FSM, intentar auto-lanzar la app antes de responder
        if (stateMachine == null) {
            Log.e("HCE_SERVICE", "HCE State Machine is not initialized. Flutter has not called init().")
            try {
                val pm: PackageManager = applicationContext.packageManager
                val launchIntent = pm.getLaunchIntentForPackage(applicationContext.packageName)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    launchIntent.putExtra("launched_via_hce", true)
                    launchIntent.putExtra("hce_event", "apdu_received")
                    applicationContext.startActivity(launchIntent)
                }
            } catch (e: Exception) {
                Log.w("HCE_SERVICE", "Auto-launch failed: ${e.message}")
            }
            return conditionsNotSatisfiedResponse
        }

        try {
            val pm: PackageManager = applicationContext.packageManager
            val launchIntent = pm.getLaunchIntentForPackage(applicationContext.packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                launchIntent.putExtra("launched_via_hce", true)
                launchIntent.putExtra("hce_event", "apdu_received")
                applicationContext.startActivity(launchIntent)
            }
        } catch (e: Exception) {
            Log.w("HCE_SERVICE", "Auto-launch failed: ${e.message}")
        }


        val responseApdu: ByteArray = stateMachine.processCommand(commandApdu)

        Log.d("HCE_SERVICE", "<-- Response: ${responseApdu.toHex()}")

        Intent().also { intent ->
            intent.action = "io.flutter.plugins.nfc_host_card_emulation.TRANSACTION"
            intent.putExtra("command", commandApdu)
            intent.putExtra("response", responseApdu)
            intent.putExtra("launched_via_hce", true)
            sendBroadcast(intent)
        }

        return responseApdu
    }

    override fun onDeactivated(reason: Int) {
        Log.d("HCE_SERVICE", "Deactivated, reason: $reason")
        HceManager.stateMachine?.onDeactivated()

        Intent().also { intent ->
            intent.action = "io.flutter.plugins.nfc_host_card_emulation.DEACTIVATED"
            intent.putExtra("reason", reason)
            intent.putExtra("launched_via_hce", true)
            sendBroadcast(intent)
        }
    }
}