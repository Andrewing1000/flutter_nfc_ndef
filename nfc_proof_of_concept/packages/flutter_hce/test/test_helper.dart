import 'dart:typed_data';
import 'package:flutter_hce/flutter_hce.dart';

/// Helper class for creating test data structures
class TestHelper {
  /// Creates a simple text NDEF record for testing
  static NdefRecord createTextRecord(String text, {String language = 'en'}) {
    return FlutterHce.createTextRecord(text, language: language);
  }

  /// Creates multiple text NDEF records for testing
  static List<NdefRecord> createTextRecords(List<String> texts) {
    return texts.map((text) => FlutterHce.createTextRecord(text)).toList();
  }

  /// Creates a URI NDEF record for testing
  static NdefRecord createUriRecord(String uri) {
    return FlutterHce.createUriRecord(uri);
  }

  /// Creates mixed test records with different types
  static List<NdefRecord> createMixedTestRecords() {
    return [
      FlutterHce.createTextRecord('Hello World!'),
      FlutterHce.createUriRecord('https://flutter.dev'),
      FlutterHce.createRawRecord(
        type: 'application/json',
        payload: Uint8List.fromList('{"test": true}'.codeUnits),
      ),
    ];
  }

  /// Creates a raw NDEF record for custom testing
  static NdefRecord createCustomRecord({
    required String type,
    required List<int> payload,
    Uint8List? id,
  }) {
    return FlutterHce.createRawRecord(
      type: type,
      payload: Uint8List.fromList(payload),
      id: id,
    );
  }

  /// Creates test records with specified size for performance testing
  static List<NdefRecord> createSizedTestRecords(int totalSizeBytes) {
    final contentSize = totalSizeBytes - 20; // Account for NDEF headers
    final content = 'A' * contentSize;
    return [FlutterHce.createTextRecord(content)];
  }

  /// Simulates initialization with test records
  static Future<bool> initWithTestRecords({
    List<NdefRecord>? records,
    bool isWritable = true,
    int maxNdefFileSize = 2048,
  }) async {
    final testRecords = records ??
        [
          FlutterHce.createTextRecord('Test Message'),
          FlutterHce.createUriRecord('https://example.com'),
        ];

    return await FlutterHce.init(
      records: testRecords,
      isWritable: isWritable,
      maxNdefFileSize: maxNdefFileSize,
    );
  }

  /// Creates test HCE transaction event (for mocking)
  static HceTransactionEvent createMockTransaction({
    HceEventType type = HceEventType.transaction,
    Uint8List? command,
    Uint8List? response,
    int? reason,
  }) {
    return HceTransactionEvent(
      type: type,
      command: command ?? Uint8List.fromList([0x00, 0xA4, 0x04, 0x00]),
      response: response ?? Uint8List.fromList([0x90, 0x00]),
      reason: reason,
    );
  }

  /// Validates NDEF record structure
  static bool isValidNdefRecord(NdefRecord record) {
    return record.type.isNotEmpty && record.payload.isNotEmpty;
  }

  /// Validates list of NDEF records
  static bool areValidNdefRecords(List<NdefRecord> records) {
    return records.isNotEmpty &&
        records.every((record) => isValidNdefRecord(record));
  }

  /// Creates test data for error scenarios
  static List<NdefRecord> createOversizedRecords(int maxFileSize) {
    final oversizedContent = 'A' * (maxFileSize + 100);
    return [FlutterHce.createTextRecord(oversizedContent)];
  }

  /// Creates empty records list for error testing
  static List<NdefRecord> createEmptyRecords() {
    return [];
  }

  /// Compares two NDEF records for equality
  static bool compareNdefRecords(NdefRecord a, NdefRecord b) {
    return a.type == b.type &&
        a.id == b.id &&
        _compareUint8Lists(a.payload, b.payload);
  }

  /// Compares two lists of NDEF records
  static bool compareNdefRecordLists(List<NdefRecord> a, List<NdefRecord> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!compareNdefRecords(a[i], b[i])) return false;
    }
    return true;
  }

  /// Helper to compare Uint8List objects
  static bool _compareUint8Lists(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Test constants
  static const String defaultTestMessage = 'Test HCE Message';
  static const String defaultTestUri = 'https://flutter.dev';
  static const int defaultMaxFileSize = 2048;
  static const String defaultLanguage = 'en';
}
