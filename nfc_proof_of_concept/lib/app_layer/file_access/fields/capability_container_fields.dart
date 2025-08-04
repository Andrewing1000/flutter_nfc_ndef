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
  static final v2_0 = CcMappingVersionField._internal(0x20);

  CcMappingVersionField._internal(int version) : super(size: 1, name: "MappingVersion") {
    buffer[0] = version;
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