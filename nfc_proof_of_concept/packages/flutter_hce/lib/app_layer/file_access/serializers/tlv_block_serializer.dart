import '../../field.dart';
import '../fields/tlv_block_fields.dart';

/// Serializer for a complete File Control TLV (Tag-Length-Value) block.
/// This class assembles the individual fields into a single 8-byte structure.
class FileControlTlv extends ApduSerializer {
  late final TlvTag tag;
  final TlvLength tagLength = TlvLength.forFileControl;
  late final FileIdField fileId;
  late final MaxFileSizeField maxFileSize;
  final ReadAccessField readAccess = ReadAccessField.granted;
  late final WriteAccessField writeAccess;

  /// Named constructor for a standard NDEF File Control TLV.
  /// Uses the standard NDEF Tag (0x04) and File ID (0xE104).
  FileControlTlv.ndef({
    required int maxNdefFileSize,
    required bool isNdefWritable,
  }) : super(name: "NDEF File Control TLV") {
    tag = TlvTag.ndef;
    fileId = FileIdField.forNdef;
    maxFileSize = MaxFileSizeField(maxNdefFileSize);
    writeAccess = WriteAccessField.fromByte(isNdefWritable ? 0x00 : 0xFF);
  }

  /// Named constructor for a Proprietary File Control TLV.
  /// Uses the standard Proprietary Tag (0x05) and a custom File ID.
  FileControlTlv.proprietary({
    required int proprietaryFileId,
    required int maxProprietaryFileSize,
    required bool isProprietaryWritable,
  }) : super(name: "Proprietary File Control TLV") {
    tag = TlvTag.proprietary;
    fileId = FileIdField(proprietaryFileId);
    maxFileSize = MaxFileSizeField(maxProprietaryFileSize);
    writeAccess =
        WriteAccessField.fromByte(isProprietaryWritable ? 0x00 : 0xFF);
  }

  @override
  void setFields() {
    fields = [
      tag,
      tagLength,
      fileId,
      maxFileSize,
      readAccess,
      writeAccess,
    ];
  }
}
