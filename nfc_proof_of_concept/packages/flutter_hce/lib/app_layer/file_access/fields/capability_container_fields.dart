import '../../field.dart';

class CcLenField extends ApduField {
  static final defaultLen = CcLenField(15);

  CcLenField(int len) : super(size: 2, name: "CCLEN") {
    if (len < 15 || len > 0xFFFF) {
      throw ArgumentError('Capability Container length must be >= 15.');
    }
    buffer[0] = (len >> 8) & 0xFF;
    buffer[1] = len & 0xFF;
  }
}

class CcMappingVersionField extends ApduField {
  static final v2_0 =
      CcMappingVersionField._internal(0x20, name: "MappingVersion (2.0)");

  CcMappingVersionField._internal(int version, {required String name})
      : super(size: 1, name: name) {
    buffer[0] = version;
  }

  /// Smart constructor that tries to return existing static final instances first
  factory CcMappingVersionField.fromByte(int version, {String? name}) {
    // Try to match with existing static final instances
    if (version == 0x20) {
      return v2_0;
    }

    // If no match found, create new instance
    final majorVersion = (version >> 4) & 0x0F;
    final minorVersion = version & 0x0F;
    final effectiveName =
        name ?? "MappingVersion ($majorVersion.$minorVersion)";
    return CcMappingVersionField._internal(version, name: effectiveName);
  }
}

class CcMaxApduDataSizeField extends ApduField {
  static final defaultMLe = CcMaxApduDataSizeField.mLe(0x00FF);
  static final defaultMLc = CcMaxApduDataSizeField.mLc(0x00FF);

  CcMaxApduDataSizeField.mLe(int size) : super(size: 2, name: "MLe") {
    if (size <= 0 || size > 0xFFFF) {
      throw ArgumentError('MLe size must be a positive 16-bit integer.');
    }
    buffer[0] = (size >> 8) & 0xFF;
    buffer[1] = size & 0xFF;
  }
  CcMaxApduDataSizeField.mLc(int size) : super(size: 2, name: "MLc") {
    if (size <= 0 || size > 0xFFFF) {
      throw ArgumentError('MLc size must be a positive 16-bit integer.');
    }
    buffer[0] = (size >> 8) & 0xFF;
    buffer[1] = size & 0xFF;
  }
}
