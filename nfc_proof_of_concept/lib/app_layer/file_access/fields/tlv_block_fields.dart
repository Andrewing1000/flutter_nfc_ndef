import '../../field.dart';

class TlvTag extends ApduField {
  static final ndef = TlvTag._internal(0x04, name: "Tag (NDEF)");
  static final proprietary = TlvTag._internal(0x05, name: "Tag (Proprietary)");

  TlvTag._internal(int tag, {required String name}) : super(size: 1, name: name) {
    buffer[0] = tag;
  }
}

class TlvLength extends ApduField {
  static final forFileControl = TlvLength._internal(0x06);

  TlvLength._internal(int len) : super(size: 1, name: "Length") {
    buffer[0] = len;
  }
}

class FileIdField extends ApduField {
  static final forNdef = FileIdField(0xE104);

  FileIdField(int fileId) : super(size: 2, name: "File ID") {
    if (fileId < 0 || fileId > 0xFFFF) {
      throw ArgumentError('File ID must be a 16-bit unsigned integer.');
    }
    buffer[0] = (fileId >> 8) & 0xFF;
    buffer[1] = fileId & 0xFF;
  }
}

class MaxFileSizeField extends ApduField {
  MaxFileSizeField(int size) : super(size: 2, name: "Max File Size") {
    if (size < 11 || size > 0xFFFF) {
      throw ArgumentError('Max File Size is invalid. Must be >= 11 bytes.');
    }
    buffer[0] = (size >> 8) & 0xFF;
    buffer[1] = size & 0xFF;
  }
}

class ReadAccessField extends ApduField {
  static final granted = ReadAccessField._internal(0x00);

  ReadAccessField._internal(int access) : super(size: 1, name: "Read Access") {
    buffer[0] = access;
  }
}

class WriteAccessField extends ApduField {
  static final granted = WriteAccessField(isWritable: true);
  static final denied = WriteAccessField(isWritable: false);

  WriteAccessField({required bool isWritable}) : super(size: 1, name: "Write Access") {
    buffer[0] = isWritable ? 0x00 : 0xFF;
  }
}