import '../../field.dart';

class ApduStatusWord extends ApduField {
  static final ok = ApduStatusWord._internal(0x90, 0x00, name: "SW (OK)");
  static final fileNotFound = ApduStatusWord._internal(0x6A, 0x82, name: "SW (File Not Found)");
  static final wrongP1P2 = ApduStatusWord._internal(0x6A, 0x86, name: "SW (Incorrect P1-P2)");
  static final wrongOffset = ApduStatusWord._internal(0x6B, 0x00, name: "SW (Wrong Offset)");
  static final wrongLength = ApduStatusWord._internal(0x67, 0x00, name: "SW (Wrong Length)");
  static final conditionsNotSatisfied = ApduStatusWord._internal(0x69, 0x85, name: "SW (Conditions Not Satisfied)");
  static final insNotSupported = ApduStatusWord._internal(0x6D, 0x00, name: "SW (INS Not Supported)");
  static final claNotSupported = ApduStatusWord._internal(0x6E, 0x00, name: "SW (CLA Not Supported)");

  ApduStatusWord._internal(int sw1, int sw2, {required String name}) : super(size: 2, name: name) {
    buffer[0] = sw1;
    buffer[1] = sw2;
  }
}