import '../../field.dart';

class ApduClass extends ApduField {
  static final standard = ApduClass._internal(0x00);

  ApduClass._internal(int claByte) : super(size: 1, name: "CLA") {
    buffer[0] = claByte;
  }
}

class ApduInstruction extends ApduField {
  static const int SELECT_BYTE = 0xA4;
  static const int READ_BINARY_BYTE = 0xB0;
  static const int UPDATE_BINARY_BYTE = 0xD6;

  static final select = ApduInstruction._internal(SELECT_BYTE, name: "INS (SELECT)");
  static final readBinary = ApduInstruction._internal(READ_BINARY_BYTE, name: "INS (READ_BINARY)");
  static final updateBinary = ApduInstruction._internal(UPDATE_BINARY_BYTE, name: "INS (UPDATE_BINARY)");

  ApduInstruction._internal(int insByte, {required String name}) : super(size: 1, name: name) {
    buffer[0] = insByte;
  }
  
  ApduInstruction(int insByte, {required String name}) : super(size: 1, name: name) {
    buffer[0] = insByte;
  }
}

class ApduParams extends ApduField {
  static final byName = ApduParams(p1: 0x04, p2: 0x00, name: "P1-P2 (ByName)");
  static final byFileId = ApduParams(p1: 0x00, p2: 0x0C, name: "P1-P2 (ByFileID)");

  factory ApduParams.forOffset(int offset) {
    if (offset < 0 || offset > 0xFFFF) {
      throw ArgumentError('Offset must be a 16-bit unsigned integer (0-65535).');
    }
    final p1 = (offset >> 8) & 0xFF;
    final p2 = offset & 0xFF;
    return ApduParams(p1: p1, p2: p2, name: "P1-P2 (Offset)");
  }
  
  ApduParams({required int p1, required int p2, required String name}) : super(size: 2, name: name) {
    buffer[0] = p1;
    buffer[1] = p2;
  }
}

class ApduLc extends ApduField {
  ApduLc({required int lc}) : super(size: 1, name: "Lc") {
    if (lc < 0 || lc > 255) {
      throw ArgumentError('Lc must be an 8-bit unsigned integer (0-255).');
    }
    buffer[0] = lc;
  }
}

class ApduLe extends ApduField {
  ApduLe({required int le}) : super(size: 1, name: "Le") {
    if (le < 0 || le > 255) {
      throw ArgumentError('Le must be an 8-bit unsigned integer (0-255). Use 0 for 256 bytes.');
    }
    buffer[0] = le;
  }
}