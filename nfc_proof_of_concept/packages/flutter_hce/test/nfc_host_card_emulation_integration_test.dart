import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hce/flutter_hce.dart';

void main() {
  group('FlutterHce Integration Tests', () {
    late List<NdefRecord> testRecords;
    late Uint8List testAid;

    setUp(() async {
      // Standard NDEF AID for testing
      testAid = Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);

      // Create test records for each test
      testRecords = [
        FlutterHce.createTextRecord('Test Message 1'),
        FlutterHce.createTextRecord('Test Message 2'),
      ];

      // Initialize HCE for each test
      await FlutterHce.init(aid: testAid, records: testRecords);
    });

    testWidgets('HCE initialization test', (tester) async {
      // Test that HCE can be initialized successfully
      expect(await FlutterHce.isStateMachineInitialized(), true,
          reason: 'State machine should be initialized after init()');
    });

    testWidgets('NFC state check test', (tester) async {
      // Test NFC state checking
      final nfcState = await FlutterHce.checkNfcState();
      expect(
          ['enabled', 'disabled', 'not_supported', 'unknown']
              .contains(nfcState),
          true,
          reason: 'NFC state should be one of the valid values');
    });

    testWidgets('NDEF record creation helpers test', (tester) async {
      // Test text record creation
      final textRecord =
          FlutterHce.createTextRecord('Hello World!', language: 'en');
      expect(textRecord.type, 'T');
      expect(textRecord.payload.isNotEmpty, true);
      expect(textRecord.id, null);

      // Test URI record creation
      final uriRecord = FlutterHce.createUriRecord('https://flutter.dev');
      expect(uriRecord.type, 'U');
      expect(uriRecord.payload.isNotEmpty, true);

      // Test raw record creation
      final customPayload = Uint8List.fromList([0x01, 0x02, 0x03]);
      final rawRecord = FlutterHce.createRawRecord(
        type: 'X',
        payload: customPayload,
      );
      expect(rawRecord.type, 'X');
      expect(rawRecord.payload, customPayload);
    });

    testWidgets('Multiple record types test', (tester) async {
      final mixedRecords = [
        FlutterHce.createTextRecord('Plain text message'),
        FlutterHce.createUriRecord('https://example.com'),
        FlutterHce.createRawRecord(
          type: 'custom/app',
          payload: Uint8List.fromList('{"key":"value"}'.codeUnits),
        ),
      ];

      final success = await FlutterHce.init(
        aid: testAid,
        records: mixedRecords,
        isWritable: false,
        maxNdefFileSize: 4096,
      );

      expect(success, true,
          reason:
              'Should successfully initialize with different NDEF record types');
      expect(await FlutterHce.isStateMachineInitialized(), true);
    });

    testWidgets('Large content test', (tester) async {
      // Test with larger content
      final largeContent = 'A' * 1000; // 1KB content
      final largeRecords = [
        FlutterHce.createTextRecord(largeContent),
      ];

      final success = await FlutterHce.init(
        aid: testAid,
        records: largeRecords,
        maxNdefFileSize: 2048, // 2KB limit
      );

      expect(success, true,
          reason: 'Should handle large content within limits');
    });

    testWidgets('HCE Transaction Stream test', (tester) async {
      // Test that transaction stream is available
      final stream = FlutterHce.transactionEvents;
      expect(stream, isNotNull);

      // Test stream subscription (won't get events in test environment)
      bool canSubscribe = false;
      try {
        final subscription = stream.listen((event) {
          // Verify event structure
          expect(event, isA<HceTransactionEvent>());
          expect(event.type,
              isIn([HceEventType.transaction, HceEventType.deactivated]));
        });
        canSubscribe = true;
        await subscription.cancel();
      } catch (e) {
        // Stream might not work in test environment
        canSubscribe = false;
      }

      // In test environment, just verify we can access the stream
      expect(canSubscribe, true,
          reason: 'Should be able to subscribe to transaction events');
    });

    testWidgets('Reinitialize with different records test', (tester) async {
      // Initialize with first set of records
      final firstRecords = [FlutterHce.createTextRecord('First message')];
      await FlutterHce.init(aid: testAid, records: firstRecords);
      expect(await FlutterHce.isStateMachineInitialized(), true);

      // Reinitialize with different records
      final secondRecords = [
        FlutterHce.createTextRecord('Second message'),
        FlutterHce.createUriRecord('https://updated.com'),
      ];

      final success =
          await FlutterHce.init(aid: testAid, records: secondRecords);
      expect(success, true,
          reason: 'Should be able to reinitialize with different records');
    });

    testWidgets('Error handling test', (tester) async {
      // Test initialization with empty records
      expect(
        () async => await FlutterHce.init(aid: testAid, records: []),
        throwsA(isA<FlutterHceException>()),
        reason: 'Should throw exception for empty records list',
      );

      // Test with oversized content
      final oversizedContent = 'A' * 3000; // 3KB content
      final oversizedRecords = [FlutterHce.createTextRecord(oversizedContent)];

      expect(
        () async => await FlutterHce.init(
          aid: testAid,
          records: oversizedRecords,
          maxNdefFileSize: 1024, // 1KB limit - smaller than content
        ),
        throwsA(isA<FlutterHceException>()),
        reason: 'Should throw exception when content exceeds max file size',
      );
    });

    testWidgets('NFC state enum conversion test', (tester) async {
      // Test NfcState enum helper
      expect(NfcState.fromString('enabled'), NfcState.enabled);
      expect(NfcState.fromString('disabled'), NfcState.disabled);
      expect(NfcState.fromString('not_supported'), NfcState.notSupported);
      expect(NfcState.fromString('unknown'), NfcState.unknown);
      expect(NfcState.fromString('invalid'), NfcState.unknown);
    });

    testWidgets('Text record payload format test', (tester) async {
      final record = FlutterHce.createTextRecord('Hello', language: 'en');
      final payload = record.payload;

      // Text record format: [flags][language_length][language][text]
      expect(payload[0], 2); // Language length (flags = language.length)
      expect(payload[1], 101); // 'e' character
      expect(payload[2], 110); // 'n' character
      expect(payload[3], 72); // 'H' character (start of "Hello")
      expect(payload[4], 101); // 'e' character
    });

    testWidgets('URI record payload format test', (tester) async {
      final record = FlutterHce.createUriRecord('http://example.com');
      final payload = record.payload;

      // URI record format: [identifier_code][uri]
      expect(payload[0], 0); // No abbreviation
      expect(payload[1], 104); // 'h' character (start of "http://example.com")
    });
  });
}
