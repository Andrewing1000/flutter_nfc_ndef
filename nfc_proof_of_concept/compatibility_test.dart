import 'dart:typed_data';
import 'packages/flutter_hce/lib/app_layer/utils/apdu_command_parser.dart';

void main() {
  print('=== Verificación de Compatibilidad Flutter-Kotlin ===\n');

  testSelectCommand();
  testReadBinaryCommand();
  testUpdateBinaryCommand();
  testParsingCompatibility();
}

void testSelectCommand() {
  print('1. Prueba SELECT Command:');

  // Test SELECT NDEF Application
  final selectNdef = ApduCommandParser.selectByName(
    applicationId: [0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01],
  );
  final ndefBytes = selectNdef.toBytes();
  print('   SELECT NDEF App: ${bytesToHex(ndefBytes)}');

  // Expected: 00 A4 00 0C 07 D2 76 00 00 85 01 01
  final expectedNdef = [
    0x00,
    0xA4,
    0x00,
    0x0C,
    0x07,
    0xD2,
    0x76,
    0x00,
    0x00,
    0x85,
    0x01,
    0x01
  ];
  print('   Expected:       ${bytesToHex(Uint8List.fromList(expectedNdef))}');
  print('   ✓ Match: ${listEquals(ndefBytes.toList(), expectedNdef)}\n');

  // Test SELECT CC File
  final selectCC = ApduCommandParser.selectCapabilityContainer();
  final ccBytes = selectCC.toBytes();
  print('   SELECT CC File: ${bytesToHex(ccBytes)}');

  // Expected: 00 A4 00 0C 02 E1 03
  final expectedCC = [0x00, 0xA4, 0x00, 0x0C, 0x02, 0xE1, 0x03];
  print('   Expected:       ${bytesToHex(Uint8List.fromList(expectedCC))}');
  print('   ✓ Match: ${listEquals(ccBytes.toList(), expectedCC)}\n');
}

void testReadBinaryCommand() {
  print('2. Prueba READ BINARY Command:');

  // Test READ BINARY offset 0, length 15
  final readBinary = ApduCommandParser.readBinary(offset: 0, length: 15);
  final readBytes = readBinary.toBytes();
  print('   READ BINARY(0,15): ${bytesToHex(readBytes)}');

  // Expected: 00 B0 00 00 0F
  final expected = [0x00, 0xB0, 0x00, 0x00, 0x0F];
  print('   Expected:          ${bytesToHex(Uint8List.fromList(expected))}');
  print('   ✓ Match: ${listEquals(readBytes.toList(), expected)}\n');

  // Test READ BINARY with offset 256
  final readBinary256 = ApduCommandParser.readBinary(offset: 256, length: 100);
  final readBytes256 = readBinary256.toBytes();
  print('   READ BINARY(256,100): ${bytesToHex(readBytes256)}');

  // Expected: 00 B0 01 00 64
  final expected256 = [0x00, 0xB0, 0x01, 0x00, 0x64];
  print(
      '   Expected:             ${bytesToHex(Uint8List.fromList(expected256))}');
  print('   ✓ Match: ${listEquals(readBytes256.toList(), expected256)}\n');
}

void testUpdateBinaryCommand() {
  print('3. Prueba UPDATE BINARY Command:');

  // Test UPDATE BINARY with simple data
  final testData = [0x48, 0x65, 0x6C, 0x6C, 0x6F]; // "Hello"
  final updateBinary =
      ApduCommandParser.updateBinary(data: testData, offset: 0);
  final updateBytes = updateBinary.toBytes();
  print('   UPDATE BINARY(0, "Hello"): ${bytesToHex(updateBytes)}');

  // Expected: 00 D6 00 00 05 48 65 6C 6C 6F
  final expected = [0x00, 0xD6, 0x00, 0x00, 0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F];
  print(
      '   Expected:                  ${bytesToHex(Uint8List.fromList(expected))}');
  print('   ✓ Match: ${listEquals(updateBytes.toList(), expected)}\n');

  // Test UPDATE BINARY with offset
  final updateBinary100 =
      ApduCommandParser.updateBinary(data: [0xFF, 0x00, 0xFF], offset: 100);
  final updateBytes100 = updateBinary100.toBytes();
  print('   UPDATE BINARY(100, data): ${bytesToHex(updateBytes100)}');

  // Expected: 00 D6 00 64 03 FF 00 FF
  final expected100 = [0x00, 0xD6, 0x00, 0x64, 0x03, 0xFF, 0x00, 0xFF];
  print(
      '   Expected:                 ${bytesToHex(Uint8List.fromList(expected100))}');
  print('   ✓ Match: ${listEquals(updateBytes100.toList(), expected100)}\n');
}

void testParsingCompatibility() {
  print('4. Prueba de Parsing (Round-trip):');

  // Create a command, serialize it, then parse it back
  final originalCommand = ApduCommandParser.selectByName(
    applicationId: [0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01],
  );
  final serializedBytes = originalCommand.toBytes();

  // Parse it back
  final parsedCommand = ApduCommandParser.fromBytes(serializedBytes);

  print('   Original: $originalCommand');
  print('   Parsed:   $parsedCommand');
  print(
      '   ✓ Type match: ${originalCommand.commandType == parsedCommand.commandType}');
  print(
      '   ✓ Bytes match: ${listEquals(originalCommand.toBytes().toList(), parsedCommand.toBytes().toList())}\n');

  // Test with READ BINARY
  final originalRead = ApduCommandParser.readBinary(offset: 512, length: 200);
  final serializedReadBytes = originalRead.toBytes();
  final parsedRead = ApduCommandParser.fromBytes(serializedReadBytes);

  print('   Original READ: $originalRead');
  print('   Parsed READ:   $parsedRead');
  print(
      '   ✓ Offset match: ${originalRead.binaryOffset == parsedRead.binaryOffset}');
  print(
      '   ✓ Length match: ${originalRead.readLength == parsedRead.readLength}\n');
}

String bytesToHex(Uint8List bytes) {
  return bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

bool listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
