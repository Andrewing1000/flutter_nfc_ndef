package io.flutter.plugins.nfc_host_card_emulation

import android.content.Intent
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log

class CardEmulationService : HostApduService() {
    companion object {
        private const val TAG = "CardEmulationService"
    }

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        val response = if (commandApdu != null) {
            val machine = HceManager.stateMachine
            if (machine == null) {
                Log.e(TAG, "HCE State Machine not initialized")
                ByteArray(0)
            } else {
                try {
                    machine.processCommand(commandApdu)
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing APDU command", e)
                    ByteArray(0)
                }
            }
        } else {
            Log.e(TAG, "Received null APDU command")
            ByteArray(0)
        }

        // Broadcast the transaction details
        val intent = Intent("io.flutter.plugins.nfc_host_card_emulation.TRANSACTION")
            .apply {
                putExtra("command", commandApdu)
                putExtra("response", response)
            }
        sendBroadcast(intent)

        return response
    }

    override fun onDeactivated(reason: Int) {
        // Broadcast the deactivation event
        val intent = Intent("io.flutter.plugins.nfc_host_card_emulation.DEACTIVATED")
            .apply {
                putExtra("reason", reason)
            }
        sendBroadcast(intent)
    }
}
