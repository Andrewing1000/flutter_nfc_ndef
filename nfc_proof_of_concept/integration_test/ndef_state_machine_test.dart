import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_hce/flutter_hce.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_message_serializer.dart'
    as dart_msg;
import 'package:flutter_hce/app_layer/test_helpers/ndef_type4_flow.dart';
import 'package:flutter_hce/app_layer/utils/apdu_command_parser.dart';
import 'package:flutter_hce/app_layer/file_access/fields/command_fields.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  int sw1(ApduResponse r) => r.statusWord.buffer[0];
  int sw2(ApduResponse r) => r.statusWord.buffer[1];

  group('NDEF Type 4 – Comprehensive', () {
    testWidgets(
        'reads back the same JSON+Text records initialized on Kotlin SM',
        (tester) async {
      final jsonRecord =
          NdefRecordSerializer.json({'amount': 123, 'currency': 'USD'});
      final textRecord = NdefRecordSerializer.text('hello-world', 'en');

      final dartMessage = dart_msg.NdefMessageSerializer.fromRecords(
        records: [
          jsonRecord,
          textRecord,
        ],
      );
      final expectedPayload = dartMessage.buffer;

      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x98]);

      final ok = await FlutterHceManager.instance.initialize(
        aid: aid,
        records: [jsonRecord, textRecord],
        isWritable: false,
      );
      expect(ok, isTrue);

      final flow = NdefType4ReaderFlow(aid: aid);
      final fileBytes = await flow.readAll();

      expect(fileBytes.length >= 2, isTrue);
      final nlen = (fileBytes[0] << 8) + fileBytes[1];
      expect(nlen, expectedPayload.length);

      final readPayload = fileBytes.sublist(2);
      final readMsg = dart_msg.NdefMessageSerializer.fromBytes(readPayload);
      expect(readMsg.buffer.length, expectedPayload.length);

      final r0 = readMsg.records[0];
      expect(r0.jsonContent, isNotNull);
      expect(r0.jsonContent!['amount'], 123);
      expect(r0.jsonContent!['currency'], 'USD');

      final r1 = readMsg.records[1];
      expect(r1.textContent, 'hello-world');
      expect(r1.textLanguage, 'en');
    });

    testWidgets('wrong AID select returns 6A82 (File Not Found)',
        (tester) async {
      // Arrange
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

    testWidgets(
        'read too-long length (256) returns 6700 and wrong offset returns 6B00',
        (tester) async {
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x98]);
      final rec = NdefRecordSerializer.text('payload', 'en');
      expect(
          await FlutterHceManager.instance.initialize(aid: aid, records: [rec]),
          isTrue);

      await FlutterHceManager.instance.processApdu(
          ApduCommandParser.selectByName(applicationId: aid).toBytes());
      await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectNdefFile().toBytes());

      final commandCls = ApduClass.standard.buffer;
      final commandIns = ApduInstruction.readBinary.buffer;
      final commandOff = ApduParams.forOffset(0).buffer;
      final commandLen = ByteData(2)..setInt16(0, 256, Endian.big);

      final bufferBuilder = BytesBuilder();
      bufferBuilder.add(commandCls);
      bufferBuilder.add(commandIns);
      bufferBuilder.add(commandOff);
      bufferBuilder.add(commandLen.buffer.asUint8List());

      final r1 = await FlutterHceManager.instance.processApdu(bufferBuilder.takeBytes());
      print("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
      print('${sw1(r1).toRadixString(16)}, ${sw2(r1).toRadixString(16)}');
      expect(sw1(r1), 0x67);
      expect(sw2(r1), 0x00);

      final lenResp = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readNdefLength().toBytes());
      final nlen = (lenResp.buffer[0] << 8) + lenResp.buffer[1];
      final wrongOff =
          ApduCommandParser.readBinary(offset: nlen + 2, length: 4);
      final r2 =
          await FlutterHceManager.instance.processApdu(wrongOff.toBytes());
      expect(sw1(r2), 0x6B);
      expect(sw2(r2), 0x00);
    });

    testWidgets('write blocked when not writable returns 6985', (tester) async {
      // Arrange
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x98]);
      final rec = NdefRecordSerializer.text('ro', 'en');
      expect(
          await FlutterHceManager.instance
              .initialize(aid: aid, records: [rec], isWritable: false),
          isTrue);

      // Select app + NDEF
      await FlutterHceManager.instance.processApdu(
          ApduCommandParser.selectByName(applicationId: aid).toBytes());
      await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectNdefFile().toBytes());

      // Try update NLEN=0
      final beginWrite =
          ApduCommandParser.updateBinary(data: const [0x00, 0x00], offset: 0);
      final resp =
          await FlutterHceManager.instance.processApdu(beginWrite.toBytes());
      expect(sw1(resp), 0x69);
      expect(sw2(resp), 0x85); // conditionsNotSatisfied
    });

    testWidgets(
        'full write sequence (NLEN=0, write chunks, finalize NLEN) and read back',
        (tester) async {
      // Arrange writable
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x99]);
      final initial = NdefRecordSerializer.text('initial', 'en');
      expect(
          await FlutterHceManager.instance
              .initialize(aid: aid, records: [initial], isWritable: true),
          isTrue);

      // Build new message to write: JSON + text
      final newJson = NdefRecordSerializer.json({'ok': true, 'v': 42});
      final newText = NdefRecordSerializer.text('updated', 'en');
      final newMsg = dart_msg.NdefMessageSerializer.fromRecords(
          records: [newJson, newText]);
      final payload = newMsg.buffer; // NDEF message (without NLEN)

      // Select app + NDEF
      await FlutterHceManager.instance.processApdu(
          ApduCommandParser.selectByName(applicationId: aid).toBytes());
      await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectNdefFile().toBytes());

      // Begin write: NLEN=0
      var apdu =
          ApduCommandParser.updateBinary(data: const [0x00, 0x00], offset: 0);
      var resp = await FlutterHceManager.instance.processApdu(apdu.toBytes());
      expect(sw1(resp), 0x90);
      expect(sw2(resp), 0x00);

      // Write data area in chunks at offset >=2
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

    testWidgets('re-select CC then NDEF and read CC returns data with 9000',
        (tester) async {
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x9B]);
      final rec = NdefRecordSerializer.text('cc', 'en');
      expect(
          await FlutterHceManager.instance.initialize(aid: aid, records: [rec]),
          isTrue);

      await FlutterHceManager.instance.processApdu(
          ApduCommandParser.selectByName(applicationId: aid).toBytes());
      await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectCapabilityContainer().toBytes());
      final cc = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readCapabilityContainer().toBytes());
      expect(sw1(cc), 0x90);
      expect(sw2(cc), 0x00);

      await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectNdefFile().toBytes());
      final len = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readNdefLength().toBytes());
      expect(sw1(len), 0x90);
      expect(sw2(len), 0x00);
    });
  });
}
