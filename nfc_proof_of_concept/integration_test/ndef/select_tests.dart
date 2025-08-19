import 'package:flutter_test/flutter_test.dart';

import 'package:integration_test/integration_test.dart';

import 'dart:typed_data';
import 'package:flutter_hce/flutter_hce.dart';
import 'package:flutter_hce/app_layer/utils/apdu_command_parser.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  int sw1(ApduResponse r) => r.statusWord.buffer[0];
  int sw2(ApduResponse r) => r.statusWord.buffer[1];

  group('NDEF Type 4 – Select', () {
    testWidgets('wrong AID select returns 6A82 (File Not Found)',
        (tester) async {
      final realAid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x98]);
      final jsonRecord = NdefRecordSerializer.json({'foo': 'bar'});
      final ok = await FlutterHceManager.instance.initialize(
        aid: realAid,
        records: [jsonRecord],
      );
      expect(ok, isTrue);

      final badAid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x99]);
      final selectBad = ApduCommandParser.selectByName(applicationId: badAid);
      final resp =
          await FlutterHceManager.instance.processApdu(selectBad.toBytes());
      expect(sw1(resp), 0x6A);
      expect(sw2(resp), 0x82);
    });

    testWidgets('select bad file id under APP_SELECTED returns 6A82',
        (tester) async {
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x98]);
      final rec = NdefRecordSerializer.text('x', 'en');
      expect(
          await FlutterHceManager.instance.initialize(aid: aid, records: [rec]),
          isTrue);

      final selectApp = ApduCommandParser.selectByName(applicationId: aid);
      await FlutterHceManager.instance.processApdu(selectApp.toBytes());

      final badFile =
          ApduCommandParser.selectByFileId(fileId: const [0xE1, 0x05]);
      final resp =
          await FlutterHceManager.instance.processApdu(badFile.toBytes());
      expect(sw1(resp), 0x6A);
      expect(sw2(resp), 0x82);
    });
  });
}
