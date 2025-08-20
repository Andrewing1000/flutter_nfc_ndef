import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_hce/flutter_hce.dart';
import 'package:flutter_hce/app_layer/utils/apdu_command_parser.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_record_serializer.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_message_serializer.dart' as dart_msg;
import 'package:flutter_hce/app_layer/test_helpers/ndef_type4_flow.dart';

// -----------------------------------------------------------------------------
// Helper: APDU forger (solo para tests)
// -----------------------------------------------------------------------------
class ApduForge {
  static int _hi(int x) => (x >> 8) & 0xFF;
  static int _lo(int x) => x & 0xFF;

  // READ BINARY corto (Le 1 byte)
  static Uint8List readShort({required int offset, required int le}) {
    return Uint8List.fromList([0x00, 0xB0, _hi(offset), _lo(offset), le & 0xFF]);
  }

  // READ BINARY extendido (Le 2 bytes): 00 | LeHi | LeLo
  static Uint8List readExtended({required int offset, required int le}) {
    return Uint8List.fromList([
      0x00, 0xB0, _hi(offset), _lo(offset),
      0x00, // extended marker
      (le >> 8) & 0xFF, le & 0xFF,
    ]);
  }
}

// -----------------------------------------------------------------------------
// Utilidades breves
// -----------------------------------------------------------------------------
int sw1(ApduResponse r) => r.statusWord.buffer[0];
int sw2(ApduResponse r) => r.statusWord.buffer[1];
String swHex(ApduResponse r) =>
    r.statusWord.buffer.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

Future<void> _selectApp(Uint8List aid) async {
  final sel = ApduCommandParser.selectByName(applicationId: aid);
  final r = await FlutterHceManager.instance.processApdu(sel.toBytes());
  expect(swHex(r), '9000', reason: 'Debe seleccionar la aplicación (AID) primero.');
}

Future<void> _selectNdef() async {
  final r = await FlutterHceManager.instance
      .processApdu(ApduCommandParser.selectNdefFile().toBytes());
  expect(swHex(r), '9000', reason: 'Debe seleccionar el EF NDEF.');
}

Future<void> _selectCC() async {
  final r = await FlutterHceManager.instance
      .processApdu(ApduCommandParser.selectCapabilityContainer().toBytes());
  expect(swHex(r), '9000', reason: 'Debe seleccionar el EF CC.');
}

Future<int> _readNlen() async {
  final lenResp = await FlutterHceManager.instance
      .processApdu(ApduCommandParser.readNdefLength().toBytes());
  expect(swHex(lenResp), '9000');
  return (lenResp.buffer[0] << 8) + lenResp.buffer[1];
}

Uint8List _concat(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (s, b) => s + b.length);
  final out = Uint8List(total);
  var off = 0;
  for (final p in parts) {
    out.setRange(off, off + p.length, p);
    off += p.length;
  }
  return out;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NDEF Type 4 – Read (cobertura ampliada)', () {
    testWidgets('1) Lee el mismo JSON+Text inicializado (E2E con flow.readAll)', (tester) async {
      final jsonRecord = NdefRecordSerializer.json({'amount': 123, 'currency': 'USD'});
      final textRecord = NdefRecordSerializer.text('hello-world', 'en');
      final msg = dart_msg.NdefMessageSerializer.fromRecords(records: [jsonRecord, textRecord]);
      final expectedPayload = msg.buffer;

      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x98]);
      final ok = await FlutterHceManager.instance
          .initialize(aid: aid, records: [jsonRecord, textRecord], isWritable: false);
      expect(ok, isTrue);

      final flow = NdefType4ReaderFlow(aid: aid);
      final fileBytes = await flow.readAll(); // NLEN(2) + payload
      expect(fileBytes.length >= 2, isTrue);

      final nlen = (fileBytes[0] << 8) + fileBytes[1];
      expect(nlen, expectedPayload.length);

      final readPayload = fileBytes.sublist(2);
      expect(readPayload.length, expectedPayload.length);

      final readMsg = dart_msg.NdefMessageSerializer.fromBytes(readPayload);
      expect(readMsg.records.length, 2);
      expect(readMsg.records[0].jsonContent?['amount'], 123);
      expect(readMsg.records[0].jsonContent?['currency'], 'USD');
      expect(readMsg.records[1].textContent, 'hello-world');
      expect(readMsg.records[1].textLanguage, 'en');
    });

    testWidgets('2) NLEN (offset 0, len 2) devuelve exactamente dos bytes y 9000', (tester) async {
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x99]);
      final rec = NdefRecordSerializer.text('alpha', 'en');
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec]), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final lenResp = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readNdefLength().toBytes());
      expect(swHex(lenResp), '9000');
      expect(lenResp.buffer.length, 2);
      final nlen = (lenResp.buffer[0] << 8) + lenResp.buffer[1];
      expect(nlen > 0, isTrue);
    });

    testWidgets('3) Lectura directa del payload completo (offset=2, Le=NLEN)', (tester) async {
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x9A]);
      final r0 = NdefRecordSerializer.json({'k': 'v'});
      final r1 = NdefRecordSerializer.text('bravo', 'en');
      final msg = dart_msg.NdefMessageSerializer.fromRecords(records: [r0, r1]);
      final expectedPayload = msg.buffer;

      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [r0, r1]), isTrue);
      await _selectApp(aid);
      await _selectNdef();

      final nlen = await _readNlen();
      expect(nlen, expectedPayload.length);

      final apdu = ApduCommandParser.readBinary(offset: 2, length: nlen);
      final resp = await FlutterHceManager.instance.processApdu(apdu.toBytes());
      expect(swHex(resp), '9000');
      expect(resp.buffer.length, nlen);
      expect(resp.buffer, expectedPayload);
    });

    testWidgets('4) Lectura por chunks 240/240… reconstruye exactamente el payload', (tester) async {
      // Construye un payload > 240 y no múltiplo de 240 para probar el último chunk parcial
      final bigText = List.filled(530, 'x').join();
      final rText = NdefRecordSerializer.text(bigText, 'en');
      final msg = dart_msg.NdefMessageSerializer.fromRecords(records: [rText]);
      final expectedPayload = msg.buffer;

      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x9B]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rText]), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final nlen = await _readNlen();
      expect(nlen, expectedPayload.length);

      final parts = <Uint8List>[];
      var off = 2;
      const chunk = 240;
      while (off < nlen + 2) {
        final remaining = nlen + 2 - off;
        final le = remaining > chunk ? chunk : remaining;
        final apdu = ApduCommandParser.readBinary(offset: off, length: le);
        final resp = await FlutterHceManager.instance.processApdu(apdu.toBytes());
        expect(swHex(resp), '9000');
        parts.add(Uint8List.fromList(resp.buffer));
        off += le;
      }
      final reassembled = _concat(parts);
      expect(reassembled.length, expectedPayload.length);
      expect(reassembled, expectedPayload);
    });

    testWidgets('5) Lectura con Le=255 cuando NLEN<255 devuelve payload completo (9000)', (tester) async {
      final rec = NdefRecordSerializer.text('short', 'en');
      final msg = dart_msg.NdefMessageSerializer.fromRecords(records: [rec]);
      final expected = msg.buffer;

      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x9C]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec]), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final nlen = await _readNlen();
      expect(nlen, expected.length);

      final apdu = ApduCommandParser.readBinary(offset: 2, length: 255);
      final resp = await FlutterHceManager.instance.processApdu(apdu.toBytes());
      expect(swHex(resp), '9000');
      expect(resp.buffer.length, expected.length);
      expect(resp.buffer, expected);
    });

    testWidgets('6) Le=256 (0x00 short) → 6700 y offset fuera de rango → 6B00', (tester) async {
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x9D]);
      final rec = NdefRecordSerializer.text('payload', 'en');
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec]), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final tooLong = ApduCommandParser.readBinary(offset: 0, length: 256);
      final r1 = await FlutterHceManager.instance.processApdu(tooLong.toBytes());
      expect(sw1(r1), 0x67);
      expect(sw2(r1), 0x00);

      final lenResp = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readNdefLength().toBytes());
      final nlen = (lenResp.buffer[0] << 8) + lenResp.buffer[1];

      final wrongOff = ApduCommandParser.readBinary(offset: nlen + 2, length: 4);
      final r2 = await FlutterHceManager.instance.processApdu(wrongOff.toBytes());
      expect(sw1(r2), 0x6B);
      expect(sw2(r2), 0x00);
    });

    testWidgets('7) Le extendido (2 bytes) no soportado → 6700', (tester) async {
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x9E]);
      final rec = NdefRecordSerializer.text('ext', 'en');
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec]), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final rExt = await FlutterHceManager.instance
          .processApdu(ApduForge.readExtended(offset: 0, le: 300));
      expect(swHex(rExt), '6700');
    });

    testWidgets('8) Re-selección CC → leer CC (9000), luego NDEF → leer NLEN (9000)', (tester) async {
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0x9F]);
      final rec = NdefRecordSerializer.text('cc', 'en');
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec]), isTrue);

      await _selectApp(aid);
      await _selectCC();

      final cc = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readCapabilityContainer().toBytes());
      expect(swHex(cc), '9000');
      expect(cc.buffer.length >= 15, isTrue, reason: 'CC típica ≥ 15 bytes');

      await _selectNdef();
      final len = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readNdefLength().toBytes());
      expect(swHex(len), '9000');
      expect(len.buffer.length, 2);
    });

    testWidgets('9) Leer NLEN alto y bajo byte por separado (offset 0 y 1)', (tester) async {
      final rec = NdefRecordSerializer.text('delta', 'en');
      final msg = dart_msg.NdefMessageSerializer.fromRecords(records: [rec]);

      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0xA0]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec]), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final nlen = await _readNlen();
      expect(nlen, msg.buffer.length);

      // Lee 1 byte (NLEN alto)
      final hi = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readBinary(offset: 0, length: 1).toBytes());
      expect(swHex(hi), '9000');
      expect(hi.buffer.length, 1);

      // Lee 1 byte (NLEN bajo)
      final lo = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readBinary(offset: 1, length: 1).toBytes());
      expect(swHex(lo), '9000');
      expect(lo.buffer.length, 1);

      final reNlen = (hi.buffer[0] << 8) + lo.buffer[0];
      expect(reNlen, nlen);
    });

    testWidgets('10) Leer payload con (offset=2, Le=NLEN+1) → 6B00 (se pasa del final)', (tester) async {
      final rec = NdefRecordSerializer.text('edge', 'en');
      final msg = dart_msg.NdefMessageSerializer.fromRecords(records: [rec]);

      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0xA1]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec]), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final nlen = await _readNlen();
      expect(nlen, msg.buffer.length);

      final apdu = ApduCommandParser.readBinary(offset: 2, length: nlen + 1);
      final r = await FlutterHceManager.instance.processApdu(apdu.toBytes());
      expect(swHex(r), '6B00');
    });

    testWidgets('11) Intentar leer sin seleccionar EF (solo AID) → 6986', (tester) async {
      final rec = NdefRecordSerializer.text('no-ef', 'en');
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0xA2]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec]), isTrue);

      await _selectApp(aid);
      final apdu = ApduCommandParser.readBinary(offset: 0, length: 2);
      final r = await FlutterHceManager.instance.processApdu(apdu.toBytes());
      expect(swHex(r), '6986'); // Command not allowed (no current EF)
    });

    testWidgets('12) Lectura exacta del último byte del payload (offset = NLEN+1, Le=1) → 9000', (tester) async {
      final rec = NdefRecordSerializer.text('tail', 'en');
      final msg = dart_msg.NdefMessageSerializer.fromRecords(records: [rec]);

      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0xA3]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec]), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final nlen = await _readNlen();
      expect(nlen, msg.buffer.length);

      // Último byte del archivo NDEF está en offset = 2 + (NLEN - 1)
      final lastOffset = 2 + nlen - 1;
      final apdu = ApduCommandParser.readBinary(offset: lastOffset, length: 1);
      final r = await FlutterHceManager.instance.processApdu(apdu.toBytes());
      expect(swHex(r), '9000');
      expect(r.buffer.length, 1);
      expect(r.buffer[0], msg.buffer.last);
    });

    testWidgets('13) Lectura de 0 bytes no es válida (Le=0 short → 256) → 6700', (tester) async {
      final rec = NdefRecordSerializer.text('z', 'en');
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0xA4]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec]), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final apdu = ApduForge.readShort(offset: 2, le: 0x00); // Le=0 → 256
      final r = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(r), '6700');
    });

    testWidgets('14) Alternar CC ⇄ NDEF múltiples veces mantiene contexto y lecturas válidas', (tester) async {
      final rec = NdefRecordSerializer.text('switch', 'en');
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0xA5]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec]), isTrue);

      await _selectApp(aid);

      // CC
      await _selectCC();
      final cc1 = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readCapabilityContainer().toBytes());
      expect(swHex(cc1), '9000');

      // NDEF
      await _selectNdef();
      final l1 = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readNdefLength().toBytes());
      expect(swHex(l1), '9000');

      // CC otra vez
      await _selectCC();
      final cc2 = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readCapabilityContainer().toBytes());
      expect(swHex(cc2), '9000');
      expect(cc2.buffer.length >= 15, isTrue);

      // NDEF otra vez
      await _selectNdef();
      final l2 = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.readNdefLength().toBytes());
      expect(swHex(l2), '9000');
      expect(l2.buffer.length, 2);
    });
  });
}
