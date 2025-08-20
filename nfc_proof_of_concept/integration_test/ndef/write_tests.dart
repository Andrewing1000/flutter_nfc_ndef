import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_hce/flutter_hce.dart';
import 'package:flutter_hce/app_layer/utils/apdu_command_parser.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_record_serializer.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_message_serializer.dart' as dart_msg;
import 'package:flutter_hce/app_layer/test_helpers/ndef_type4_flow.dart';

// -----------------------------------------------------------------------------
// Helper: forjador de APDUs UPDATE/RAW (solo para tests)
// -----------------------------------------------------------------------------
class ApduForge {
  static int _hi(int x) => (x >> 8) & 0xFF;
  static int _lo(int x) => x & 0xFF;

  // UPDATE BINARY short Lc (1 byte)
  static Uint8List updateShort({required int offset, required List<int> data}) {
    return Uint8List.fromList([0x00, 0xD6, _hi(offset), _lo(offset), data.length & 0xFF, ...data]);
    // Nota: data.length puede ser 0 (Lc=0) para probar 6700.
  }

  // UPDATE BINARY extended Lc (no soportado; provoca 6700 en este SM)
  // Estructura: 00 | LcHi | LcLo | DATA...
  static Uint8List updateExtended({required int offset, required List<int> data}) {
    final len = data.length;
    return Uint8List.fromList([
      0x00, 0xD6, _hi(offset), _lo(offset),
      0x00, (len >> 8) & 0xFF, len & 0xFF,
      ...data,
    ]);
  }

  // APDU crudo con CLA/INS/P1/P2 arbitrarios (sin Lc/Le).
  static Uint8List raw({
    int cla = 0x00,
    required int ins,
    int p1 = 0x00,
    int p2 = 0x00,
  }) {
    return Uint8List.fromList([cla & 0xFF, ins & 0xFF, p1 & 0xFF, p2 & 0xFF]);
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
  expect(swHex(r), '9000', reason: 'Debe seleccionar el EF NDEF para UPDATE.');
}

Future<void> _selectCC() async {
  final r = await FlutterHceManager.instance
      .processApdu(ApduCommandParser.selectCapabilityContainer().toBytes());
  expect(swHex(r), '9000', reason: 'Debe seleccionar el EF CC correctamente.');
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

  group('NDEF Type 4 – Write (cobertura ampliada)', () {
    testWidgets('1) write bloqueado cuando isWritable=false → 6985', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xD0]);
      final rec = NdefRecordSerializer.text('ro', 'en');
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec], isWritable: false), isTrue);
      await _selectApp(aid);
      await _selectNdef();
      final beginWrite = ApduCommandParser.updateBinary(data: const [0x00, 0x00], offset: 0);
      final resp = await FlutterHceManager.instance.processApdu(beginWrite.toBytes());
      expect(swHex(resp), '6985');
    });

    testWidgets('2) secuencia completa: NLEN=0 → chunks → NLEN=final y lectura OK', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xD1]);
      final initial = NdefRecordSerializer.text('initial', 'en');
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [initial], isWritable: true), isTrue);

      final newJson = NdefRecordSerializer.json({'ok': true, 'v': 42});
      final newText = NdefRecordSerializer.text('updated', 'en');
      final newMsg = dart_msg.NdefMessageSerializer.fromRecords(records: [newJson, newText]);
      final payload = newMsg.buffer;

      await _selectApp(aid);
      await _selectNdef();

      // NLEN=0
      var apdu = ApduCommandParser.updateBinary(data: const [0x00, 0x00], offset: 0);
      var resp = await FlutterHceManager.instance.processApdu(apdu.toBytes());
      expect(swHex(resp), '9000');

      // Chunks
      var offset = 2;
      var idx = 0;
      const chunk = 200;
      while (idx < payload.length) {
        final end = (idx + chunk) > payload.length ? payload.length : (idx + chunk);
        final slice = payload.sublist(idx, end);
        apdu = ApduCommandParser.updateBinary(data: slice, offset: offset);
        resp = await FlutterHceManager.instance.processApdu(apdu.toBytes());
        expect(swHex(resp), '9000');
        idx = end;
        offset += slice.length;
      }

      // Final NLEN
      final nlenHi = (payload.length >> 8) & 0xFF;
      final nlenLo = payload.length & 0xFF;
      apdu = ApduCommandParser.updateBinary(data: [nlenHi, nlenLo], offset: 0);
      resp = await FlutterHceManager.instance.processApdu(apdu.toBytes());
      expect(swHex(resp), '9000');

      // Verifica lectura
      final flow = NdefType4ReaderFlow(aid: aid);
      final file = await flow.readAll();
      final readMsg = dart_msg.NdefMessageSerializer.fromBytes(file.sublist(2));
      expect(readMsg.records.length, 2);
      expect(readMsg.records[0].jsonContent?['ok'], true);
      expect(readMsg.records[0].jsonContent?['v'], 42);
      expect(readMsg.records[1].textContent, 'updated');
    });

    testWidgets('3) escribir data antes de NLEN=0 (offset≥2) → 6985', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xD2]);
      final rec = NdefRecordSerializer.text('x', 'en');
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [rec], isWritable: true), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final apdu = ApduForge.updateShort(offset: 2, data: [1,2,3]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6985'); // condiciones no satisfechas
    });

    testWidgets('4) NLEN parcial en offset=1 → 6A86 (wrong P1P2)', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xD3]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [NdefRecordSerializer.text('x','en')], isWritable: true), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final bad = ApduForge.updateShort(offset: 1, data: [0x00]); // parcial
      final resp = await FlutterHceManager.instance.processApdu(bad);
      expect(swHex(resp), '6A86');
    });

    testWidgets('5) NLEN con Lc=1 en offset=0 (solo un byte) → 6700', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xD4]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [NdefRecordSerializer.text('y','en')], isWritable: true), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final apdu = ApduForge.updateShort(offset: 0, data: [0x00]); // Lc=1
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6700');
    });

    testWidgets('6) NLEN con Lc extendido (00 | 00 02) → 6700', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xD5]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [NdefRecordSerializer.text('z','en')], isWritable: true), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final apdu = ApduForge.updateExtended(offset: 0, data: [0x00, 0x00]); // extended Lc
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6700');
    });

    testWidgets('7) UPDATE con CLA no soportada (0x80) → 6E00', (tester) async {
      final apdu = ApduForge.raw(cla: 0x80, ins: 0xD6, p1: 0x00, p2: 0x00);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6E00');
    });

    testWidgets('8) UPDATE con INS desconocido (0xFF) → 6D00', (tester) async {
      final apdu = ApduForge.raw(ins: 0xFF, p1: 0x00, p2: 0x00);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6D00');
    });

    testWidgets('9) UPDATE con offset fuera de rango (0xFFFF) → 6B00', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xD6]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [NdefRecordSerializer.text('oob','en')], isWritable: true), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final apdu = ApduForge.updateShort(offset: 0xFFFF, data: [0xAA]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6B00');
    });

    testWidgets('10) UPDATE con Lc=0 (sin datos) → 6700', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xD7]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [NdefRecordSerializer.text('zero','en')], isWritable: true), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      final apdu = ApduForge.updateShort(offset: 2, data: const []);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6700');
    });

    testWidgets('11) UPDATE sobre EF CC (no NDEF) → 6986', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xD8]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [NdefRecordSerializer.text('cc','en')], isWritable: true), isTrue);

      await _selectApp(aid);
      await _selectCC();

      final apdu = ApduForge.updateShort(offset: 0, data: [0x00, 0x00]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6986'); // command not allowed en EF incorrecto
    });

    testWidgets('12) Tras escribir y cerrar (NLEN final), nuevo UPDATE sin arrancar (NLEN=0) → 6985', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xD9]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [NdefRecordSerializer.text('q','en')], isWritable: true), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      // Escribe un mensaje corto válido
      final rec = NdefRecordSerializer.text('done', 'en');
      final msg = dart_msg.NdefMessageSerializer.fromRecords(records: [rec]);
      final payload = msg.buffer;

      // Start
      var r = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.updateBinary(data: const [0,0], offset: 0).toBytes());
      expect(swHex(r), '9000');

      // Data
      var off = 2;
      const ck = 200;
      var idx = 0;
      while (idx < payload.length) {
        final end = (idx + ck) > payload.length ? payload.length : (idx + ck);
        final slice = payload.sublist(idx, end);
        r = await FlutterHceManager.instance.processApdu(
          ApduCommandParser.updateBinary(data: slice, offset: off).toBytes(),
        );
        expect(swHex(r), '9000');
        off += slice.length;
        idx = end;
      }

      // Close
      final nlenHi = (payload.length >> 8) & 0xFF;
      final nlenLo = payload.length & 0xFF;
      r = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.updateBinary(data: [nlenHi, nlenLo], offset: 0).toBytes());
      expect(swHex(r), '9000');

      // Intentar escribir otra vez (sin reiniciar con NLEN=0)
      final again = ApduForge.updateShort(offset: 2, data: [0x11, 0x22]);
      final resp = await FlutterHceManager.instance.processApdu(again);
      expect(swHex(resp), '6985');
    });

    testWidgets('13) Escribir payload grande (>480) en chunks de 240 y leer de vuelta', (tester) async {
      final largeText = List.filled(530, 'x').join();
      final rText = NdefRecordSerializer.text(largeText, 'en');
      final msg = dart_msg.NdefMessageSerializer.fromRecords(records: [rText]);
      final payload = msg.buffer;

      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xDA]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [NdefRecordSerializer.text('seed','en')], isWritable: true), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      // Start write
      var r = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.updateBinary(data: const [0,0], offset: 0).toBytes());
      expect(swHex(r), '9000');

      // Data chunks
      var off = 2;
      var idx = 0;
      const chunk = 240;
      while (idx < payload.length) {
        final end = (idx + chunk) > payload.length ? payload.length : (idx + chunk);
        final slice = payload.sublist(idx, end);
        r = await FlutterHceManager.instance.processApdu(
          ApduCommandParser.updateBinary(data: slice, offset: off).toBytes(),
        );
        expect(swHex(r), '9000');
        off += slice.length;
        idx = end;
      }

      // Close
      final nlenHi = (payload.length >> 8) & 0xFF;
      final nlenLo = payload.length & 0xFF;
      r = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.updateBinary(data: [nlenHi, nlenLo], offset: 0).toBytes());
      expect(swHex(r), '9000');

      // Read back and compare
      final flow = NdefType4ReaderFlow(aid: aid);
      final file = await flow.readAll();
      final readPayload = file.sublist(2);
      expect(readPayload.length, payload.length);
      expect(readPayload, payload);
    });

    testWidgets('14) Escribir mensaje vacío: NLEN=0 → (sin data) → NLEN=0 y leer NLEN=0', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xDB]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [NdefRecordSerializer.text('seed','en')], isWritable: true), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      // Start (NLEN=0)
      var r = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.updateBinary(data: const [0,0], offset: 0).toBytes());
      expect(swHex(r), '9000');

      // Cerrar con NLEN=0 (sin escribir datos)
      r = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.updateBinary(data: const [0,0], offset: 0).toBytes());
      expect(swHex(r), '9000');

      // Leer NLEN y verificar 0
      final nlen = await _readNlen();
      expect(nlen, 0);

      // readAll debería retornar solo los 2 bytes de NLEN
      final flow = NdefType4ReaderFlow(aid: aid);
      final file = await flow.readAll();
      expect(file.length, 2);
      expect(file[0], 0);
      expect(file[1], 0);
    });

    testWidgets('15) UPDATE sin EF seleccionado (solo AID seleccionado) → 6986', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xDC]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [NdefRecordSerializer.text('seed','en')], isWritable: true), isTrue);

      await _selectApp(aid);
      // No seleccionar NDEF
      final apdu = ApduForge.updateShort(offset: 0, data: [0x00, 0x00]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6986');
    });

    testWidgets('16) UPDATE de datos en offset=0 (más de 2 bytes) → 6A86', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xDD]);
      expect(await FlutterHceManager.instance.initialize(aid: aid, records: [NdefRecordSerializer.text('seed','en')], isWritable: true), isTrue);

      await _selectApp(aid);
      await _selectNdef();

      // Intento escribir 3 bytes en offset 0 (área NLEN debe ser exactamente 2 bytes).
      final apdu = ApduForge.updateShort(offset: 0, data: [0x01, 0x02, 0x03]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6A86');
    });
  });
}
