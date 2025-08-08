package io.flutter.plugins.nfc_host_card_emulation.file_access.serializers

import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduSerializer
import io.flutter.plugins.nfc_host_card_emulation.file_access.fields.*

class FileControlTlv private constructor(
    name: String,
    val tag: TlvTag,
    val fileId: FileIdField,
    val maxFileSize: MaxFileSizeField,
    val writeAccess: WriteAccessField
) : ApduSerializer(name) {

    private val tagLength = TlvLength.forFileControl
    private val readAccess = ReadAccessField.granted

    companion object {
        @JvmStatic
        fun ndef(
            maxNdefFileSize: Int,
            isNdefWritable: Boolean
        ): FileControlTlv {
            return FileControlTlv(
                name = "NDEF File Control TLV",
                tag = TlvTag.ndef,
                fileId = FileIdField.forNdef,
                maxFileSize = MaxFileSizeField(maxNdefFileSize),
                writeAccess = WriteAccessField(isNdefWritable)
            )
        }

        @JvmStatic
        fun proprietary(
            proprietaryFileId: Int,
            maxProprietaryFileSize: Int,
            isProprietaryWritable: Boolean
        ): FileControlTlv {
            return FileControlTlv(
                name = "Proprietary File Control TLV",
                tag = TlvTag.proprietary,
                fileId = FileIdField(proprietaryFileId),
                maxFileSize = MaxFileSizeField(maxProprietaryFileSize),
                writeAccess = WriteAccessField(isProprietaryWritable)
            )
        }
    }

    override fun setFields() {
        fields = listOf(
            tag,
            tagLength,
            fileId,
            maxFileSize,
            readAccess,
            writeAccess,
        )
    }
}