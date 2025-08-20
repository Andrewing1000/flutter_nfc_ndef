import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_hce/flutter_hce.dart';
import 'package:flutter_hce/app_layer/utils/apdu_command_parser.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_record_serializer.dart';

// -----------------------------------------------------------------------------
// Helper: forjador de APDUs SELECT (solo para tests)
// -----------------------------------------------------------------------------
class ApduForge {
  static Uint8List selectByName({
    required List<int> aid,
    int p1 = 0x04,
    int p2 = 0x00,
    int? lcOverride,
  }) {
    final lc = lcOverride ?? aid.length;
    return Uint8List.fromList([
      0x00, 0xA4, p1 & 0xFF, p2 & 0xFF, lc & 0xFF, ...aid,
    ]);
  }

  /// SELECT by name con Lc explícito y data arbitraria (permite mismatch Lc != data.length).
  static Uint8List selectByNameWithLcData({
    required List<int> data, // bytes DF name
    required int lc,
    int p1 = 0x04,
    int p2 = 0x00,
  }) {
    return Uint8List.fromList([
      0x00, 0xA4, p1 & 0xFF, p2 & 0xFF, lc & 0xFF, ...data,
    ]);
  }

  /// SELECT by name con longitud extendida (no soportada en este SM).
  static Uint8List selectByNameExtended({
    required List<int> aid,
    int p1 = 0x04,
    int p2 = 0x00,
  }) {
    final len = aid.length;
    return Uint8List.fromList([
      0x00, 0xA4, p1 & 0xFF, p2 & 0xFF,
      0x00, (len >> 8) & 0xFF, len & 0xFF, // extended Lc
      ...aid,
    ]);
  }

  /// SELECT por File ID (FID) short Lc; permite Lc override y FID nulo.
  static Uint8List selectFileId({
    required int? fid, // null → sin bytes de FID
    int p1 = 0x00,
    int p2 = 0x0C,
    int? lcOverride,
  }) {
    final data = <int>[];
    if (fid != null) {
      data.add((fid >> 8) & 0xFF);
      data.add(fid & 0xFF);
    }
    final lc = lcOverride ?? data.length;
    return Uint8List.fromList([
      0x00, 0xA4, p1 & 0xFF, p2 & 0xFF, lc & 0xFF, ...data,
    ]);
  }

  /// SELECT por File ID con longitud extendida (no soportada).
  static Uint8List selectFileIdExtended({
    required int fid,
    int p1 = 0x00,
    int p2 = 0x0C,
  }) {
    return Uint8List.fromList([
      0x00, 0xA4, p1 & 0xFF, p2 & 0xFF,
      0x00, 0x00, 0x02, // extended Lc = 2
      (fid >> 8) & 0xFF, fid & 0xFF,
    ]);
  }

  /// APDU crudo con CLA/INS/P1/P2 arbitrarios (sin Lc/Le).
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

Future<void> _initApp(Uint8List aid, {String seedText = 'init', bool writable = false}) async {
  final ok = await FlutterHceManager.instance.initialize(
    aid: aid,
    records: [NdefRecordSerializer.text(seedText, 'en')],
    isWritable: writable,
  );
  expect(ok, isTrue);
}

Future<void> _selectApp(Uint8List aid) async {
  final sel = ApduCommandParser.selectByName(applicationId: aid);
  final r = await FlutterHceManager.instance.processApdu(sel.toBytes());
  expect(swHex(r), '9000', reason: 'Debe seleccionar la aplicación (AID) primero.');
}

// -----------------------------------------------------------------------------
// Pruebas
// -----------------------------------------------------------------------------
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NDEF Type 4 – Select (AID/FID) – Cobertura ampliada', () {
    testWidgets('1) SELECT by name (AID correcto) → 9000', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xB0]);
      await _initApp(aid);
      final resp = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectByName(applicationId: aid).toBytes());
      expect(swHex(resp), '9000');
    });

    testWidgets('2) SELECT by name (AID incorrecto) → 6A82', (tester) async {
      final realAid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xB1]);
      await _initApp(realAid);
      final badAid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xB2]);
      final resp = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectByName(applicationId: badAid).toBytes());
      expect(sw1(resp), 0x6A);
      expect(sw2(resp), 0x82);
    });

    testWidgets('3) Re-SELECT mismo AID (idempotente) → 9000', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xB3]);
      await _initApp(aid);
      await _selectApp(aid);
      final again = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectByName(applicationId: aid).toBytes());
      expect(swHex(again), '9000');
    });

    testWidgets('4) SELECT by name con P1 inválido (0x00) → 6A86', (tester) async {
      final aid = [0xA0,0x00,0x00,0x03,0x86,0xB4];
      final apdu = ApduForge.selectByName(aid: aid, p1: 0x00, p2: 0x00);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6A86');
    });

    testWidgets('5) SELECT by name con P2 inválido (0xFF) → 6A86', (tester) async {
      final aid = [0xA0,0x00,0x00,0x03,0x86,0xB5];
      final apdu = ApduForge.selectByName(aid: aid, p1: 0x04, p2: 0xFF);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6A86');
    });

    testWidgets('6) SELECT by name con Lc=0 (AID vacío) → 6700', (tester) async {
      final apdu = ApduForge.selectByName(aid: const [], lcOverride: 0x00);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6700');
    });

    testWidgets('7) SELECT by name con Lc≠len(data) (Lc=2, data=1 byte) → 6700', (tester) async {
      final apdu = ApduForge.selectByNameWithLcData(data: const [0xA0], lc: 0x02);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6700');
    });

    testWidgets('8) SELECT by name con longitud extendida (no soportada) → 6700', (tester) async {
      final aid = [0xA0,0x00,0x00,0x03,0x86,0xB6];
      final apdu = ApduForge.selectByNameExtended(aid: aid);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6700');
    });

    testWidgets('9) SELECT EF CC tras AID → 9000', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xB7]);
      await _initApp(aid);
      await _selectApp(aid);
      final r = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectCapabilityContainer().toBytes());
      expect(swHex(r), '9000');
    });

    testWidgets('10) SELECT EF NDEF tras AID → 9000', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xB8]);
      await _initApp(aid);
      await _selectApp(aid);
      final r = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectNdefFile().toBytes());
      expect(swHex(r), '9000');
    });

    testWidgets('11) SELECT FID inexistente bajo APP_SELECTED → 6A82', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xB9]);
      await _initApp(aid);
      await _selectApp(aid);
      final badFile = ApduCommandParser.selectByFileId(fileId: const [0xDE, 0xAD]);
      final resp = await FlutterHceManager.instance.processApdu(badFile.toBytes());
      expect(swHex(resp), '6A82');
    });

    testWidgets('12) SELECT EF (CC) sin seleccionar AID previamente → 6A82', (tester) async {
      // No se inicializa/selecciona AID en este test.
      final resp = await FlutterHceManager.instance
          .processApdu(ApduCommandParser.selectCapabilityContainer().toBytes());
      // Fuera de contexto de aplicación, el FID no existe → 6A82
      expect(swHex(resp), '6A82');
    });

    testWidgets('13) SELECT FID con Lc demasiado corto (Lc=1, faltan bytes) → 6700', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xBA]);
      await _initApp(aid);
      await _selectApp(aid);
      final apdu = ApduForge.selectFileId(fid: null, lcOverride: 0x01);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6700');
    });

    testWidgets('14) SELECT FID con Lc mayor a 2 (Lc=3, FID=2 bytes + extra) → 6700', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xBB]);
      await _initApp(aid);
      await _selectApp(aid);
      // Construimos manualmente: 00 A4 00 0C 03 E1 04 FF  → Lc=3, data=E1 04 FF
      final apdu = Uint8List.fromList([0x00,0xA4,0x00,0x0C,0x03,0xE1,0x04,0xFF]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6700');
    });

    testWidgets('15) SELECT FID con longitud extendida (no soportada) → 6700', (tester) async {
      final aid = Uint8List.fromList([0xA0,0x00,0x00,0x03,0x86,0xBC]);
      await _initApp(aid);
      await _selectApp(aid);
      final apdu = ApduForge.selectFileIdExtended(fid: 0xE104);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6700');
    });

    testWidgets('16) SELECT con CLA no soportada (0x80) → 6E00', (tester) async {
      final apdu = ApduForge.raw(cla: 0x80, ins: 0xA4, p1: 0x04, p2: 0x00);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6E00');
    });
  });
}
