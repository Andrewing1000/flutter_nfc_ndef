package com.viridian.flutter_hce.app_layer.file_access.serializers

import com.viridian.flutter_hce.app_layer.ApduSerializer
import com.viridian.flutter_hce.app_layer.file_access.fields.*

/**
 * Serializer for a complete File Control TLV (Tag-Length-Value) block.
 * This class assembles the individual fields into a single 8-byte structure.
 */
class FileControlTlv : ApduSerializer {
    private val tag: TlvTag
    private val tagLength: TlvLength = TlvLength.forFileControl
    private val fileId: FileIdField
    private val maxFileSize: MaxFileSizeField
    private val readAccess: ReadAccessField = ReadAccessField.granted
    private val writeAccess: WriteAccessField

    companion object {
        /**
         * Named constructor for a standard NDEF File Control TLV.
         * Uses the standard NDEF Tag (0x04) and File ID (0xE104).
         */
    fun ndef(maxNdefFileSize: Int, isNdefWritable: Boolean): FileControlTlv {
            return FileControlTlv(
                "NDEF File Control TLV",
                TlvTag.ndef,
                FileIdField.forNdef,
                MaxFileSizeField(maxNdefFileSize),
        WriteAccessField.fromWritable(isNdefWritable)
            )
        }

        /**
         * Named constructor for a Proprietary File Control TLV.
         * Uses the standard Proprietary Tag (0x05) and a custom File ID.
         */
    fun proprietary(
            proprietaryFileId: Int,
            maxProprietaryFileSize: Int,
            isProprietaryWritable: Boolean
        ): FileControlTlv {
            return FileControlTlv(
                "Proprietary File Control TLV",
                TlvTag.proprietary,
                FileIdField(proprietaryFileId),
                MaxFileSizeField(maxProprietaryFileSize),
        WriteAccessField.fromWritable(isProprietaryWritable)
            )
        }
    }

    private constructor(
        name: String,
        tag: TlvTag,
        fileId: FileIdField,
        maxFileSize: MaxFileSizeField,
        writeAccess: WriteAccessField
    ) : super(name) {
        this.tag = tag
        this.fileId = fileId
        this.maxFileSize = maxFileSize
        this.writeAccess = writeAccess

        // Register fields in the defined order
        register(this.tag)
        register(this.tagLength)
        register(this.fileId)
        register(this.maxFileSize)
        register(this.readAccess)
        register(this.writeAccess)
    }
}
