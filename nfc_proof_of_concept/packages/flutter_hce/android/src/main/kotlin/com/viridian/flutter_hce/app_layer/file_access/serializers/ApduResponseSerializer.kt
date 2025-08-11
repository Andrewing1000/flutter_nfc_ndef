package com.viridian.flutter_hce.app_layer.file_access.serializers

import com.viridian.flutter_hce.app_layer.ApduData
import com.viridian.flutter_hce.app_layer.ApduSerializer
import com.viridian.flutter_hce.app_layer.Bytes
import com.viridian.flutter_hce.app_layer.file_access.fields.ApduStatusWord

class ApduResponse private constructor(
    private val data: ApduData?,
    private val statusWord: ApduStatusWord,
    name: String
) : ApduSerializer(name) {

    companion object {
        fun fromBytes(rawResponse: Bytes): ApduResponse {
            require(rawResponse.size >= 2) { 
                "Invalid APDU response: must be at least 2 bytes for the status word. Got ${rawResponse.size} bytes." 
            }

            val dataLength = rawResponse.size - 2
            val responseData = if (dataLength > 0) {
                ApduData(rawResponse.sliceArray(0 until dataLength), "Response Data (Parsed)")
            } else null

            val sw1 = rawResponse[dataLength].toInt() and 0xFF
            val sw2 = rawResponse[dataLength + 1].toInt() and 0xFF
            val statusWord = ApduStatusWord.fromBytes(sw1, sw2)

            return ApduResponse(responseData, statusWord, "Parsed Response")
        }

        fun success(data: Bytes? = null): ApduResponse {
            val responseData = if (data != null && data.isNotEmpty()) {
                ApduData(data, "Response Data")
            } else null

            return ApduResponse(responseData, ApduStatusWord.ok, "Success Response")
        }

        fun error(errorStatus: ApduStatusWord): ApduResponse {
            require(errorStatus != ApduStatusWord.ok) { 
                "Cannot create an error response with SW=9000. Use success() factory." 
            }
            return ApduResponse(null, errorStatus, "Error Response")
        }
    }

    override fun setFields() {
        fields.clear()
        fields.addAll(listOfNotNull(data, statusWord))
    }
}
