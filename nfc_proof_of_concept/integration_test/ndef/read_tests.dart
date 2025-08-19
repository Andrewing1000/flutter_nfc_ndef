import 'package:flutter_test/flutter_test.dart';

import 'package:integration_test/integration_test.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_message_serializer.dart'
    as dart_msg;
import 'package:flutter_hce/app_layer/test_helpers/ndef_type4_flow.dart';
import 'dart:typed_data';
import 'package:flutter_hce/app_layer/utils/apdu_command_parser.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_record_serializer.dart';
import 'package:flutter_hce/flutter_hce.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  int sw1(ApduResponse r) => r.statusWord.buffer[0];
  int sw2(ApduResponse r) => r.statusWord.buffer[1];

  group('NDEF Type 4 – Read', () {
    testWidgets(
        'reads back the same JSON+Text records initialized on Kotlin SM',
        (tester) async {
      final jsonRecord =
          NdefRecordSerializer.json({'amount': 123, 'currency': 'USD'});
      final textRecord = NdefRecordSerializer.text('hello-world', 'en');
      final dartMessage = dart_msg.NdefMessageSerializer.fromRecords(
          records: [jsonRecord, textRecord]);
      final expectedPayload = dartMessage.buffer;
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x98]);
      final ok = await FlutterHceManager.instance.initialize(
          aid: aid, records: [jsonRecord, textRecord], isWritable: false);
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
      final readTooLong = ApduCommandParser.readBinary(offset: 0, length: 256);
      final r1 =
          await FlutterHceManager.instance.processApdu(readTooLong.toBytes());
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
