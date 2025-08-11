import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hce/flutter_hce.dart';
import 'package:flutter_hce/flutter_hce_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'test_helper.dart';

/// Mock platform implementation for testing
class MockFlutterHcePlatform
    with MockPlatformInterfaceMixin
    implements FlutterHcePlatform {
  bool initialized = false;
  List<NdefRecord> currentRecords = [];
  String nfcState = 'enabled';

  @override
  Future<bool> init({
    required List<NdefRecord> records,
    bool isWritable = false,
    int maxNdefFileSize = 2048,
  }) async {
    if (records.isEmpty) {
      throw FlutterHceException('Records list cannot be empty');
    }

    // Calculate total size
    int totalSize = 0;
    for (var record in records) {
      totalSize +=
          record.payload.length + record.type.length + 10; // Header overhead
    }

    if (totalSize > maxNdefFileSize) {
      throw FlutterHceException(
          'Content size ($totalSize bytes) exceeds maximum file size ($maxNdefFileSize bytes)');
    }

    currentRecords = List.from(records);
    initialized = true;
    return true;
  }

  @override
  Future<String> checkNfcState() async {
    return nfcState;
  }

  @override
  Future<bool> isStateMachineInitialized() async {
    return initialized;
  }

  @override
  Stream<HceTransactionEvent> get transactionEvents =>
      Stream.empty(); // Mock stream for testing

  void setNfcState(String state) {
    nfcState = state;
  }

  void reset() {
    initialized = false;
    currentRecords.clear();
    nfcState = 'enabled';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Flutter HCE Tests', () {
    late MockFlutterHcePlatform mockPlatform;

    setUp(() {
      mockPlatform = MockFlutterHcePlatform();
      FlutterHcePlatform.instance = mockPlatform;
    });

    tearDown(() {
      mockPlatform.reset();
    });

    group('Initialization Tests', () {
      test('initializes with valid NDEF records', () async {
        final records = [
          FlutterHce.createTextRecord('Hello World!'),
          FlutterHce.createUriRecord('https://flutter.dev'),
        ];

        final success = await FlutterHce.init(records: records);
        expect(success, true);
        expect(await FlutterHce.isStateMachineInitialized(), true);
      });

      test('fails initialization with empty records', () async {
        expect(
          () async => await FlutterHce.init(records: []),
          throwsA(isA<FlutterHceException>()),
        );
      });

      test('supports custom initialization parameters', () async {
        final records = [FlutterHce.createTextRecord('Test Message')];

        final success = await FlutterHce.init(
          records: records,
          isWritable: true,
          maxNdefFileSize: 4096,
        );

        expect(success, true);
        expect(await FlutterHce.isStateMachineInitialized(), true);
      });

      test('handles oversized content', () async {
        final largeContent = 'A' * 3000;
        final records = [FlutterHce.createTextRecord(largeContent)];

        expect(
          () async => await FlutterHce.init(
            records: records,
            maxNdefFileSize: 1024, // Smaller than content
          ),
          throwsA(isA<FlutterHceException>()),
        );
      });
    });

    group('NDEF Record Creation Tests', () {
      test('creates text records correctly', () async {
        final record1 = FlutterHce.createTextRecord('Hello World!');
        expect(record1.type, 'T');
        expect(record1.payload.isNotEmpty, true);
        expect(record1.id, null);

        final record2 = FlutterHce.createTextRecord('Bonjour', language: 'fr');
        expect(record2.type, 'T');
        expect(record2.payload.isNotEmpty, true);

        // Verify language code is encoded
        expect(record2.payload[0], 2); // Language length
        expect(record2.payload[1], 102); // 'f'
        expect(record2.payload[2], 114); // 'r'
      });

      test('creates URI records correctly', () async {
        final record1 = FlutterHce.createUriRecord('https://flutter.dev');
        expect(record1.type, 'U');
        expect(record1.payload.isNotEmpty, true);

        final record2 = FlutterHce.createUriRecord('http://example.com');
        expect(record2.type, 'U');
        expect(record2.payload.isNotEmpty, true);
        expect(record2.payload[0], 0); // No abbreviation
      });

      test('creates raw records correctly', () async {
        final customPayload = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
        final record = FlutterHce.createRawRecord(
          type: 'application/custom',
          payload: customPayload,
        );

        expect(record.type, 'application/custom');
        expect(record.payload, customPayload);
        expect(record.id, null);
      });

      test('creates records with custom IDs', () async {
        final customId = Uint8List.fromList([0xAB, 0xCD]);
        final record = FlutterHce.createRawRecord(
          type: 'custom',
          payload: Uint8List.fromList([0x01, 0x02]),
          id: customId,
        );

        expect(record.id, customId);
      });
    });

    group('NFC State Management Tests', () {
      test('checks NFC state correctly', () async {
        mockPlatform.setNfcState('enabled');
        expect(await FlutterHce.checkNfcState(), 'enabled');

        mockPlatform.setNfcState('disabled');
        expect(await FlutterHce.checkNfcState(), 'disabled');

        mockPlatform.setNfcState('not_supported');
        expect(await FlutterHce.checkNfcState(), 'not_supported');
      });

      test('NFC state enum conversions work', () async {
        expect(NfcState.fromString('enabled'), NfcState.enabled);
        expect(NfcState.fromString('disabled'), NfcState.disabled);
        expect(NfcState.fromString('not_supported'), NfcState.notSupported);
        expect(NfcState.fromString('unknown'), NfcState.unknown);
        expect(NfcState.fromString('invalid_value'), NfcState.unknown);
      });
    });

    group('Transaction Events Tests', () {
      test('transaction events stream is accessible', () async {
        final stream = FlutterHce.transactionEvents;
        expect(stream, isNotNull);

        // Test stream subscription
        bool canSubscribe = false;
        try {
          final subscription = stream.listen((event) {
            expect(event, isA<HceTransactionEvent>());
          });
          canSubscribe = true;
          await subscription.cancel();
        } catch (e) {
          canSubscribe = false;
        }

        expect(canSubscribe, true);
      });
    });

    group('Multiple Records Management', () {
      test('handles mixed record types', () async {
        final records = [
          FlutterHce.createTextRecord('Plain text content'),
          FlutterHce.createUriRecord('https://example.com/path'),
          FlutterHce.createRawRecord(
            type: 'application/json',
            payload: Uint8List.fromList('{"key":"value"}'.codeUnits),
          ),
        ];

        final success = await FlutterHce.init(records: records);
        expect(success, true);
        expect(mockPlatform.currentRecords.length, 3);
      });

      test('supports multiple text records', () async {
        final records = TestHelper.createTextRecords([
          'Message 1',
          'Message 2',
          'Message 3',
        ]);

        final success = await FlutterHce.init(records: records);
        expect(success, true);
        expect(mockPlatform.currentRecords.length, 3);
      });

      test('reinitializes with different records', () async {
        // First initialization
        final firstRecords = [FlutterHce.createTextRecord('First message')];
        await FlutterHce.init(records: firstRecords);
        expect(mockPlatform.currentRecords.length, 1);

        // Reinitialize with different records
        final secondRecords = [
          FlutterHce.createTextRecord('Second message'),
          FlutterHce.createUriRecord('https://updated.com'),
        ];

        final success = await FlutterHce.init(records: secondRecords);
        expect(success, true);
        expect(mockPlatform.currentRecords.length, 2);
      });
    });

    group('Text Record Payload Format Tests', () {
      test('text record has correct payload structure', () async {
        final record = FlutterHce.createTextRecord('Hello', language: 'en');
        final payload = record.payload;

        // Text record format: [flags][language_length][language][text]
        expect(payload[0], 2); // Language length
        expect(payload[1], 101); // 'e'
        expect(payload[2], 110); // 'n'
        expect(payload[3], 72); // 'H' (start of "Hello")
      });

      test('different languages encoded correctly', () async {
        final frRecord = FlutterHce.createTextRecord('Bonjour', language: 'fr');
        final payload = frRecord.payload;

        expect(payload[0], 2); // Language length
        expect(payload[1], 102); // 'f'
        expect(payload[2], 114); // 'r'
      });
    });

    group('URI Record Format Tests', () {
      test('URI record has correct payload structure', () async {
        final record = FlutterHce.createUriRecord('http://example.com');
        final payload = record.payload;

        // URI record format: [identifier_code][uri]
        expect(payload[0], 0); // No abbreviation
        expect(payload[1], 104); // 'h' (start of "http://example.com")
      });
    });
  });
}
