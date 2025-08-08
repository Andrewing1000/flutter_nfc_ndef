package io.flutter.plugins.nfc_host_card_emulation.file_access.serializers

import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduData
import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduSerializer
import io.flutter.plugins.nfc_host_card_emulation.app_layer.Bytes
import io.flutter.plugins.nfc_host_card_emulation.file_access.fields.ApduStatusWord

class ApduResponse private constructor(
    val data: ApduData?,
    val statusWord: ApduStatusWord,
    name: String
) : ApduSerializer(name) {

    companion object {
        @JvmStatic
        fun fromBytes(rawResponse: Bytes): ApduResponse {
            require(rawResponse.size >= 2) { "Invalid APDU response: must be at least 2 bytes for the status word. Got ${rawResponse.size} bytes." }

            val dataLength = rawResponse.size - 2
            val responseData = if (dataLength > 0) {
                ApduData("Response Data (Parsed)", rawResponse.sliceArray(0 until dataLength))
            } else {
                null
            }

            val sw1 = rawResponse[dataLength].toInt() and 0xFF
            val sw2 = rawResponse[dataLength + 1].toInt() and 0xFF
            val statusWord = ApduStatusWord.fromBytes(sw1, sw2)

            return ApduResponse(
                data = responseData,
                statusWord = statusWord,
                name = "Parsed Response"
            )
        }

        @JvmStatic
        fun success(data: Bytes? = null): ApduResponse {
            val responseData = if (data != null && data.isNotEmpty()) {
                ApduData("Response Data", data)
            } else {
                null
            }
            return ApduResponse(
                data = responseData,
                statusWord = ApduStatusWord.ok,
                name = "Success Response"
            )
        }

        @JvmStatic
        fun error(errorStatus: ApduStatusWord): ApduResponse {
            require(errorStatus != ApduStatusWord.ok) { "Cannot create an error response with SW=9000. Use success() factory." }
            return ApduResponse(
                data = null,
                statusWord = errorStatus,
                name = "Error Response"
            )
        }
    }

    override fun setFields() {
        fields = listOf(data, statusWord)
    }
}