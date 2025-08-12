import '../../field.dart';

class ApduStatusWord extends ApduField {
  static final ok = ApduStatusWord._internal(0x90, 0x00, name: "SW (OK)");
  static final fileNotFound =
      ApduStatusWord._internal(0x6A, 0x82, name: "SW (File Not Found)");
  static final wrongP1P2 =
      ApduStatusWord._internal(0x6A, 0x86, name: "SW (Incorrect P1-P2)");
  static final wrongOffset =
      ApduStatusWord._internal(0x6B, 0x00, name: "SW (Wrong Offset)");
  static final wrongLength =
      ApduStatusWord._internal(0x67, 0x00, name: "SW (Wrong Length)");
  static final conditionsNotSatisfied = ApduStatusWord._internal(0x69, 0x85,
      name: "SW (Conditions Not Satisfied)");
  static final insNotSupported =
      ApduStatusWord._internal(0x6D, 0x00, name: "SW (INS Not Supported)");
  static final claNotSupported =
      ApduStatusWord._internal(0x6E, 0x00, name: "SW (CLA Not Supported)");

  ApduStatusWord._internal(int sw1, int sw2, {required String name})
      : super(size: 2, name: name) {
    buffer[0] = sw1;
    buffer[1] = sw2;
  }

  /// Smart constructor that tries to return existing static final instances first
  factory ApduStatusWord.fromBytes(int sw1, int sw2, {String? name}) {
    // Try to match with existing static final instances
    if (sw1 == 0x90 && sw2 == 0x00) {
      return ok;
    } else if (sw1 == 0x6A && sw2 == 0x82) {
      return fileNotFound;
    } else if (sw1 == 0x6A && sw2 == 0x86) {
      return wrongP1P2;
    } else if (sw1 == 0x6B && sw2 == 0x00) {
      return wrongOffset;
    } else if (sw1 == 0x67 && sw2 == 0x00) {
      return wrongLength;
    } else if (sw1 == 0x69 && sw2 == 0x85) {
      return conditionsNotSatisfied;
    } else if (sw1 == 0x6D && sw2 == 0x00) {
      return insNotSupported;
    } else if (sw1 == 0x6E && sw2 == 0x00) {
      return claNotSupported;
    }

    // If no match found, create new instance
    final effectiveName = name ??
        "SW (0x${sw1.toRadixString(16).padLeft(2, '0').toUpperCase()}${sw2.toRadixString(16).padLeft(2, '0').toUpperCase()})";
    return ApduStatusWord._internal(sw1, sw2, name: effectiveName);
  }
}
