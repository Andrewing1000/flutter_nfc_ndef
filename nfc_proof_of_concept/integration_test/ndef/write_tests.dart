import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_hce/hce_manager.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_record_serializer.dart';
import 'package:flutter_hce/app_layer/utils/apdu_command_parser.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_message_serializer.dart'
    as dart_msg;
import 'package:flutter_hce/app_layer/test_helpers/ndef_type4_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  int sw1(ApduResponse r) => r.statusWord.buffer[0];
  int sw2(ApduResponse r) => r.statusWord.buffer[1];

  group('NDEF Type 4 – Write', () {
    testWidgets('write blocked when not writable returns 6985', (tester) async {
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x98]);
      final rec = NdefRecordSerializer.text('ro', 'en');
      expect(
          await FlutterHceManager.instance
              .initialize(aid: aid, records: [rec], isWritable: false),
          isTrue);
      await FlutterHceManager.instance.processApdu(
          ApduCommandParser.selectByName(applicationId: aid).toBytes());
      await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectNdefFile().toBytes());
      final beginWrite =
          ApduCommandParser.updateBinary(data: const [0x00, 0x00], offset: 0);
      final resp =
          await FlutterHceManager.instance.processApdu(beginWrite.toBytes());
      expect(sw1(resp), 0x69);
      expect(sw2(resp), 0x85);
    });

    testWidgets(
        'full write sequence (NLEN=0, write chunks, finalize NLEN) and read back',
        (tester) async {
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x99]);
      final initial = NdefRecordSerializer.text('initial', 'en');
      expect(
          await FlutterHceManager.instance
              .initialize(aid: aid, records: [initial], isWritable: true),
          isTrue);
      final newJson = NdefRecordSerializer.json({'ok': true, 'v': 42});
      final newText = NdefRecordSerializer.text('updated', 'en');
      final newMsg = dart_msg.NdefMessageSerializer.fromRecords(
          records: [newJson, newText]);
      final payload = newMsg.buffer;
      await FlutterHceManager.instance.processApdu(
          ApduCommandParser.selectByName(applicationId: aid).toBytes());
      await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectNdefFile().toBytes());
      var apdu =
          ApduCommandParser.updateBinary(data: const [0x00, 0x00], offset: 0);
      var resp = await FlutterHceManager.instance.processApdu(apdu.toBytes());
      expect(sw1(resp), 0x90);
      expect(sw2(resp), 0x00);
      int offset = 2;
      int idx = 0;
      const chunk = 200;
      while (idx < payload.length) {
        final end =
            (idx + chunk) > payload.length ? payload.length : (idx + chunk);
        final slice = payload.sublist(idx, end);
        apdu = ApduCommandParser.updateBinary(data: slice, offset: offset);
        resp = await FlutterHceManager.instance.processApdu(apdu.toBytes());
        expect(sw1(resp), 0x90);
        expect(sw2(resp), 0x00);
        idx = end;
        offset += slice.length;
      }
      final nlenHi = (payload.length >> 8) & 0xFF;
      final nlenLo = payload.length & 0xFF;
      apdu = ApduCommandParser.updateBinary(data: [nlenHi, nlenLo], offset: 0);
      resp = await FlutterHceManager.instance.processApdu(apdu.toBytes());
      expect(sw1(resp), 0x90);
      expect(sw2(resp), 0x00);
      final flow = NdefType4ReaderFlow(aid: aid);
      final file = await flow.readAll();
      final readMsg = dart_msg.NdefMessageSerializer.fromBytes(file.sublist(2));
      expect(readMsg.records.length, 2);
      expect(readMsg.records[0].jsonContent?['ok'], true);
      expect(readMsg.records[0].jsonContent?['v'], 42);
      expect(readMsg.records[1].textContent, 'updated');
    });

    testWidgets('partial NLEN write at offset 1 returns 6A86 (wrong P1P2)',
        (tester) async {
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x9A]);
      final rec = NdefRecordSerializer.text('x', 'en');
      expect(
          await FlutterHceManager.instance
              .initialize(aid: aid, records: [rec], isWritable: true),
          isTrue);
      await FlutterHceManager.instance.processApdu(
          ApduCommandParser.selectByName(applicationId: aid).toBytes());
      await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectNdefFile().toBytes());
      final bad = ApduCommandParser.updateBinary(data: const [0x00], offset: 1);
      final resp = await FlutterHceManager.instance.processApdu(bad.toBytes());
      expect(sw1(resp), 0x6A);
      expect(sw2(resp), 0x86);
    });
  });
}
