package io.flutter.plugins.nfc_host_card_emulation.app_layer.file_access.responses

data class ApduResponse(
    val sw1: Byte,
    val sw2: Byte,
    val data: ByteArray = ByteArray(0)
) {
    constructor(sw1: Int, sw2: Int, data: ByteArray = ByteArray(0)) : this(
        sw1.toByte(),
        sw2.toByte(),
        data
    )

    val sw: Int get() = ((sw1.toInt() and 0xFF) shl 8) or (sw2.toInt() and 0xFF)

    companion object {
        val SUCCESS = ApduResponse(0x90, 0x00)
        val FILE_NOT_FOUND = ApduResponse(0x6A, 0x82)
        val FILE_ACCESS_DENIED = ApduResponse(0x6A, 0x82)
        val INVALID_LE = ApduResponse(0x67, 0x00)
        val UNKNOWN_ERROR = ApduResponse(0x6F, 0x00)
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as ApduResponse

        if (sw1 != other.sw1) return false
        if (sw2 != other.sw2) return false
        return data.contentEquals(other.data)
    }

    override fun hashCode(): Int {
        var result = sw1.toInt()
        result = 31 * result + sw2.toInt()
        result = 31 * result + data.contentHashCode()
        return result
    }

    override fun toString(): String {
        return "ApduResponse(sw1=$sw1, sw2=$sw2, data=${data.contentToString()})"
    }
}
