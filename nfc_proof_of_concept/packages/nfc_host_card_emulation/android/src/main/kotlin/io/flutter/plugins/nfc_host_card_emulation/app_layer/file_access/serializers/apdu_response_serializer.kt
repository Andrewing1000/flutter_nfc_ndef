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