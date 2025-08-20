import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_hce/flutter_hce.dart';
import 'package:flutter_hce/app_layer/utils/apdu_command_parser.dart';
import 'package:flutter_hce/app_layer/utils/apdu_response_parser.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_record_serializer.dart' as dart_ndef;

// ---------- Helper para forjar APDUs inválidos (short/extended) ----------
class ApduForge {
  static int _hi(int x) => (x >> 8) & 0xFF;
  static int _lo(int x) => x & 0xFF;

  // READ BINARY short Le (1 byte)
  static Uint8List readShort({required int offset, required int le}) {
    return Uint8List.fromList([0x00, 0xB0, _hi(offset), _lo(offset), le & 0xFF]);
  }

  // READ BINARY extended Le (2 bytes): 00 | LeHi | LeLo
  static Uint8List readExtended({required int offset, required int le}) {
    return Uint8List.fromList([
      0x00, 0xB0, _hi(offset), _lo(offset),
      0x00, // extended length marker
      (le >> 8) & 0xFF, le & 0xFF,
    ]);
  }

  // UPDATE BINARY short Lc (1 byte)
  static Uint8List updateShort({required int offset, required List<int> data}) {
    return Uint8List.fromList([
      0x00, 0xD6, _hi(offset), _lo(offset),
      data.length & 0xFF, ...data,
    ]);
  }

  // UPDATE BINARY extended Lc (2 bytes): 00 | LcHi | LcLo
  static Uint8List updateExtended({required int offset, required List<int> data}) {
    final len = data.length;
    return Uint8List.fromList([
      0x00, 0xD6, _hi(offset), _lo(offset),
      0x00, (len >> 8) & 0xFF, len & 0xFF, ...data,
    ]);
  }

  // SELECT by File ID (short Lc=0x02), con posibilidad de cortar Lc
  static Uint8List selectFileId({required int? fileId, int? lcOverride}) {
    // fileId==null → no bytes de FID; lcOverride permite Lc inválido
    final data = <int>[];
    if (fileId != null) {
      data.add((fileId >> 8) & 0xFF);
      data.add(fileId & 0xFF);
    }
    final lc = lcOverride ?? data.length;
    return Uint8List.fromList([0x00, 0xA4, 0x00, 0x0C, lc, ...data]);
  }

  // SELECT by Name (AID), con control de P1/P2/Lc
  static Uint8List selectByName({
    required List<int> aid,
    int p1 = 0x04,
    int p2 = 0x00,
    int? lcOverride,
  }) {
    final lc = lcOverride ?? aid.length;
    return Uint8List.fromList([0x00, 0xA4, p1 & 0xFF, p2 & 0xFF, lc & 0xFF, ...aid]);
  }

  // APDU genérico con INS/CLA arbitrarios
  static Uint8List raw({
    int cla = 0x00,
    required int ins,
    int p1 = 0x00,
    int p2 = 0x00,
    List<int>? data,
    int? le,
  }) {
    final d = data ?? const <int>[];
    final hasData = d.isNotEmpty;
    final hasLe = le != null;
    final bytes = <int>[cla & 0xFF, ins & 0xFF, p1 & 0xFF, p2 & 0xFF];
    if (hasData) {
      bytes.add(d.length & 0xFF);
      bytes.addAll(d);
    }
    if (hasLe) bytes.add(le! & 0xFF);
    return Uint8List.fromList(bytes);
  }
}

// ---------- Utilidades breves ----------
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
  expect(swHex(r), '9000', reason: 'Debe seleccionar el EF NDEF antes de leer/escribir.');
}

Future<void> _selectCC() async {
  final r = await FlutterHceManager.instance
      .processApdu(ApduCommandParser.selectCapabilityContainer().toBytes());
  expect(swHex(r), '9000', reason: 'Debe seleccionar el EF CC para leer la CC.');
}

Future<int> _readNlen() async {
  final lenResp = await FlutterHceManager.instance
      .processApdu(ApduCommandParser.readNdefLength().toBytes());
  expect(swHex(lenResp), '9000');
  return (lenResp.buffer[0] << 8) + lenResp.buffer[1];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NDEF Type 4 — Negative/Corrupted APDU Paths', () {
    // Caso base: app no-writable por defecto, salvo donde se indique.
    final baseAid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0xC1]);

    setUp(() async {
      // Inicializa con un registro mínimo válido
      final rec = dart_ndef.NdefRecordSerializer.text('init', 'en');
      final ok = await FlutterHceManager.instance.initialize(
        aid: baseAid,
        records: [rec],
        isWritable: false,
      );
      expect(ok, isTrue);
    });

    testWidgets('1) READ BINARY con Le=0 (256) tras seleccionar NDEF → 6700', (tester) async {
      await _selectApp(baseAid);
      await _selectNdef();
      final apdu = ApduForge.readShort(offset: 0, le: 0x00); // Le=0 → 256 (short)
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6700');
    });

    testWidgets('2) READ BINARY con offset fuera de rango (nlen+2) → 6B00', (tester) async {
      await _selectApp(baseAid);
      await _selectNdef();
      final nlen = await _readNlen();
      final oobOffset = nlen + 2; // justo después del header NLEN
      final apdu = ApduForge.readShort(offset: oobOffset, le: 0x01);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6B00');
    });

    testWidgets('3) SELECT EF inexistente (0xDEAD) bajo APP_SELECTED → 6A82', (tester) async {
      await _selectApp(baseAid);
      final apdu = ApduForge.selectFileId(fileId: 0xDEAD);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6A82');
    });

    testWidgets('4) UPDATE BINARY con NLEN parcial en offset=1 → 6A86', (tester) async {
      await _selectApp(baseAid);
      await _selectNdef();
      final apdu = ApduForge.updateShort(offset: 1, data: [0x00]); // parcial
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6A86');
    });

    testWidgets('5) UPDATE BINARY cuando no-writable → 6985', (tester) async {
      await _selectApp(baseAid);
      await _selectNdef();
      final apdu = ApduForge.updateShort(offset: 0, data: [0x00, 0x00]); // NLEN=0
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6985');
    });

    testWidgets('6) SELECT file con Lc demasiado corto (1 byte para FID) → 6700', (tester) async {
      await _selectApp(baseAid);
      final apdu = ApduForge.selectFileId(fileId: null, lcOverride: 0x01); // Lc=1 sin FID completo
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6700');
    });

    testWidgets('7) READ BINARY sin EF seleccionado (solo AID) → 6986', (tester) async {
      await _selectApp(baseAid);
      final apdu = ApduForge.readShort(offset: 0, le: 0x01);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6986'); // Command not allowed (no current EF)
    });

    testWidgets('8) UPDATE BINARY sin EF seleccionado (solo AID) → 6986', (tester) async {
      await _selectApp(baseAid);
      final apdu = ApduForge.updateShort(offset: 0, data: [0x00, 0x00]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6986');
    });

    testWidgets('9) INS no soportado (0xFF) → 6D00', (tester) async {
      await _selectApp(baseAid);
      // No importa EF para probar INS desconocido
      final apdu = ApduForge.raw(ins: 0xFF, le: 0x00);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6D00');
    });

    testWidgets('10) CLA no soportado (0x80) → 6E00', (tester) async {
      await _selectApp(baseAid);
      final apdu = ApduForge.raw(cla: 0x80, ins: 0xB0, p1: 0x00, p2: 0x00, le: 0x01);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6E00');
    });

    testWidgets('11) SELECT by name con Lc=0 (AID vacío) → 6700', (tester) async {
      final apdu = ApduForge.selectByName(aid: const [], lcOverride: 0x00);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6700');
    });

    testWidgets('12) UPDATE payload en offset>=2 sin haber puesto NLEN=0 → 6985', (tester) async {
      // Re-inicializa como writable para que solo falle por protocolo, no por permiso
      final aid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x03, 0x86, 0xC2]);
      final ok = await FlutterHceManager.instance.initialize(
        aid: aid,
        records: [dart_ndef.NdefRecordSerializer.text('x', 'en')],
        isWritable: true,
      );
      expect(ok, isTrue);

      await _selectApp(aid);
      await _selectNdef();
      // Intento de escribir data sin haber enviado NLEN=0 primero
      final apdu = ApduForge.updateShort(offset: 2, data: [1, 2, 3]);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6985'); // condiciones no satisfechas
    });

    testWidgets('13) READ CC con offset fuera de rango → 6B00', (tester) async {
      await _selectApp(baseAid);
      await _selectCC();
      // CC típica ~15 bytes; leer desde offset 0x10 (16) con Le=1 debe ser OOB
      final apdu = ApduForge.readShort(offset: 0x0010, le: 0x01);
      final resp = await FlutterHceManager.instance.processApdu(apdu);
      expect(swHex(resp), '6B00');
    });

    testWidgets('14) SELECT by name con P1/P2 inválidos (P1=0x00) → 6A86', (tester) async {
      final badSel = ApduForge.selectByName(aid: baseAid, p1: 0x00, p2: 0x00);
      final resp = await FlutterHceManager.instance.processApdu(badSel);
      expect(swHex(resp), '6A86');
    });

    testWidgets('15) READ/UPDATE extended length no soportado → 6700', (tester) async {
      await _selectApp(baseAid);
      await _selectNdef();

      // READ extended Le (2 bytes) → 6700
      final rExt = ApduForge.readExtended(offset: 0, le: 300);
      final rr = await FlutterHceManager.instance.processApdu(rExt);
      expect(swHex(rr), '6700');

      // UPDATE extended Lc (2 bytes) → 6700
      final uExt = ApduForge.updateExtended(offset: 0, data: [0x00, 0x00]);
      final ur = await FlutterHceManager.instance.processApdu(uExt);
      expect(swHex(ur), '6700');
    });
  });
}
