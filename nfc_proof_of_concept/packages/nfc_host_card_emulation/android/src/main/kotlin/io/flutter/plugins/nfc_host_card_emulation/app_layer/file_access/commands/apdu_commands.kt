package io.flutter.plugins.nfc_host_card_emulation.app_layer.file_access.commands

enum class ApduClass(val value: Byte) {
    ISO7816_COMMAND(0x00),
    APPLICATION_COMMAND(0x80),
    APPLICATION_RESPONSE(0x80),
    PROPRIETARY_COMMAND(0xC0),
    PROPRIETARY_RESPONSE(0xC0)
}

sealed class ApduCommand(
    val cla: ApduClass,
    val ins: Byte,
    val p1: Byte = 0x00,
    val p2: Byte = 0x00,
    val data: ByteArray = ByteArray(0),
    val ne: Int? = null
) {
    override fun toString(): String {
        return "ApduCommand(cla=${cla.value}, ins=$ins, p1=$p1, p2=$p2, data=${data.contentToString()}, ne=$ne)"
    }
}

class SelectCommand(
    val aid: ByteArray
) : ApduCommand(
    cla = ApduClass.ISO7816_COMMAND,
    ins = 0xA4.toByte(),
    p1 = 0x04,
    p2 = 0x00,
    data = aid,
    ne = 0x00
)

class ReadBinaryCommand(
    val offset: Int,
    val length: Int
) : ApduCommand(
    cla = ApduClass.ISO7816_COMMAND,
    ins = 0xB0.toByte(),
    p1 = ((offset shr 8) and 0xFF).toByte(),
    p2 = (offset and 0xFF).toByte(),
    ne = length
)

class UpdateBinaryCommand(
    val offset: Int,
    val data: ByteArray
) : ApduCommand(
    cla = ApduClass.ISO7816_COMMAND,
    ins = 0xD6.toByte(),
    p1 = ((offset shr 8) and 0xFF).toByte(),
    p2 = (offset and 0xFF).toByte(),
    data = data
)
