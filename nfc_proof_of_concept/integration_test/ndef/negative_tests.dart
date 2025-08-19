import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'package:flutter_hce/hce_manager.dart';
import 'package:flutter_hce/app_layer/utils/apdu_response_parser.dart';

void main() {
  group('NDEF Negative/Corrupted APDU Tests', () {
    testWidgets('READ BINARY with Le=0 (256) returns 6700', (tester) async {
      // Le=0 means 256 in short APDU
      final apdu = Uint8List.fromList([0x00, 0xB0, 0x00, 0x00, 0x00]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      final parser = ApduResponseParser.fromBytes(resp.buffer);
      expect(parser.statusWordHex, '6700');
    });

    testWidgets('READ BINARY with out-of-bounds offset returns 6B00',
        (tester) async {
      // Offset set to a large value (0xFFFF)
      final apdu = Uint8List.fromList([0x00, 0xB0, 0xFF, 0xFF, 0x01]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      final parser = ApduResponseParser.fromBytes(resp.buffer);
      expect(parser.statusWordHex, '6B00');
    });

    testWidgets('SELECT file with invalid file ID returns 6A82',
        (tester) async {
      // Select file with non-existent file ID 0xDEAD
      final apdu =
          Uint8List.fromList([0x00, 0xA4, 0x00, 0x0C, 0x02, 0xDE, 0xAD]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      final parser = ApduResponseParser.fromBytes(resp.buffer);
      expect(parser.statusWordHex, '6A82');
    });

    testWidgets('UPDATE BINARY with partial NLEN at offset 1 returns 6A86',
        (tester) async {
      // Offset=1, data=0x00 (should not allow partial NLEN write)
      final apdu = Uint8List.fromList([0x00, 0xD6, 0x00, 0x01, 0x01, 0x00]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      final parser = ApduResponseParser.fromBytes(resp.buffer);
      expect(parser.statusWordHex, '6A86');
    });

    testWidgets('UPDATE BINARY when not writable returns 6985', (tester) async {
      // Try to write to NDEF file when not writable (simulate by test setup)
      // This test assumes the state machine is in a non-writable state
      final apdu =
          Uint8List.fromList([0x00, 0xD6, 0x00, 0x00, 0x02, 0x00, 0x00]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      final parser = ApduResponseParser.fromBytes(resp.buffer);
      expect(parser.statusWordHex, '6985');
    });

    testWidgets('SELECT file with too-short data returns 6700', (tester) async {
      // Select file with missing file ID bytes
      final apdu = Uint8List.fromList([0x00, 0xA4, 0x00, 0x0C, 0x01, 0xE1]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      final parser = ApduResponseParser.fromBytes(resp.buffer);
      expect(parser.statusWordHex, '6700');
    });
  });
}
