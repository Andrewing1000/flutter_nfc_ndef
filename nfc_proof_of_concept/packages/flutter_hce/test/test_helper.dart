import 'dart:typed_data';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation_platform_interface.dart';

class TestNdefRecord {
  final String type;
  final String content;

  TestNdefRecord({required this.type, required this.content});

  NdefRecordData toNdefRecordData() {
    return NdefRecordData(
        type: type, payload: Uint8List.fromList(content.codeUnits));
  }
}

class TestHelper {
  static List<NdefRecordData> createTestRecords(
      {required List<TestNdefRecord> records}) {
    return records.map((r) => r.toNdefRecordData()).toList();
  }

  static List<NdefRecordData> createSimpleTextRecords(List<String> texts) {
    return texts
        .map((text) => TestNdefRecord(type: 'text/plain', content: text)
            .toNdefRecordData())
        .toList();
  }

  static bool compareNdefRecords(
      List<NdefRecordData> a, List<NdefRecordData> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].type != b[i].type) return false;
      if (!_compareUint8Lists(a[i].payload, b[i].payload)) return false;
    }
    return true;
  }

  static bool _compareUint8Lists(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
