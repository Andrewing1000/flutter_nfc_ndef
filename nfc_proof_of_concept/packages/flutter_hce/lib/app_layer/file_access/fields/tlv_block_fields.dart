import '../../field.dart';

class TlvTag extends ApduField {
  static final ndef = TlvTag._internal(0x04, name: "Tag (NDEF)");
  static final proprietary = TlvTag._internal(0x05, name: "Tag (Proprietary)");

  TlvTag._internal(int tag, {required String name})
      : super(size: 1, name: name) {
    buffer[0] = tag;
  }

  /// Smart constructor that tries to return existing static final instances first
  factory TlvTag(int tag, {String? name}) {
    // Try to match with existing static final instances
    switch (tag) {
      case 0x04:
        return ndef;
      case 0x05:
        return proprietary;
      default:
        // If no match found, create new instance
        final effectiveName = name ??
            "Tag (0x${tag.toRadixString(16).padLeft(2, '0').toUpperCase()})";
        return TlvTag._internal(tag, name: effectiveName);
    }
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
  static final granted =
      ReadAccessField._internal(0x00, name: "Read Access (Granted)");

  ReadAccessField._internal(int access, {required String name})
      : super(size: 1, name: name) {
    buffer[0] = access;
  }

  /// Smart constructor that tries to return existing static final instances first
  factory ReadAccessField.fromByte(int accessByte, {String? name}) {
    // Try to match with existing static final instances
    if (accessByte == 0x00) {
      return granted;
    }

    // If no match found, create new instance
    final effectiveName = name ??
        "Read Access (0x${accessByte.toRadixString(16).padLeft(2, '0').toUpperCase()})";
    return ReadAccessField._internal(accessByte, name: effectiveName);
  }
}

class WriteAccessField extends ApduField {
  static final granted =
      WriteAccessField._internal(0x00, name: "Write Access (Granted)");
  static final denied =
      WriteAccessField._internal(0xFF, name: "Write Access (Denied)");

  WriteAccessField._internal(int access, {required String name})
      : super(size: 1, name: name) {
    buffer[0] = access;
  }

  /// Smart constructor that tries to return existing static final instances first
  factory WriteAccessField({required bool isWritable}) {
    return isWritable ? granted : denied;
  }

  /// Smart constructor from raw byte value
  factory WriteAccessField.fromByte(int accessByte, {String? name}) {
    // Try to match with existing static final instances
    if (accessByte == 0x00) {
      return granted;
    } else if (accessByte == 0xFF) {
      return denied;
    }

    // If no match found, create new instance
    final effectiveName = name ??
        "Write Access (0x${accessByte.toRadixString(16).padLeft(2, '0').toUpperCase()})";
    return WriteAccessField._internal(accessByte, name: effectiveName);
  }
}
