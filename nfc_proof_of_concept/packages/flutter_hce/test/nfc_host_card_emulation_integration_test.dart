import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hce/nfc_host_card_emulation.dart';
import 'package:nfc_host_card_emulation/app_layer/errors.dart';

import 'test_helper.dart';

void main() {

  group('NfcHce Integration Tests', () {
    const standardNdefFileId = 0xE104;
    late Uint8List standardAid;

    setUp(() async {
      standardAid =
          Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);
      await NfcHce.init(aid: standardAid);
    });

    tearDown(() async {
      await NfcHce.clearAllFiles();
    });

    testWidgets('Full lifecycle test with NDEF records', (tester) async {
      // Test NFC state
      expect(await NfcHce.checkDeviceNfcState(), NfcState.enabled);

      // Test setting and getting NDEF records
      final testRecords = TestHelper.createSimpleTextRecords(
          ['Test Message 1', 'Test Message 2']);

      await NfcHce.addOrUpdateNdefFile(
          fileId: standardNdefFileId, records: testRecords);

      expect(await NfcHce.hasFile(fileId: standardNdefFileId), true,
          reason: 'File should exist after creation');

      // Test clearing files
      await NfcHce.clearAllFiles();
      expect(await NfcHce.hasFile(fileId: standardNdefFileId), false,
          reason: 'File should not exist after clearing');
    });

    testWidgets('Mixed content type NDEF records test', (tester) async {
      final mixedRecords = TestHelper.createTestRecords(records: [
        TestNdefRecord(type: 'text/plain', content: 'Plain text'),
        TestNdefRecord(type: 'text/json', content: '{"key":"value"}'),
        TestNdefRecord(type: 'application/x-custom', content: 'Custom data')
      ]);

      await NfcHce.addOrUpdateNdefFile(
          fileId: standardNdefFileId, records: mixedRecords, maxFileSize: 4096);

      expect(await NfcHce.hasFile(fileId: standardNdefFileId), true,
          reason: 'Should handle different NDEF record types correctly');
    });

    testWidgets('Rapid updates test', (tester) async {
      // Test rapid updates to NDEF files
      for (var i = 0; i < 5; i++) {
        final records = TestHelper.createSimpleTextRecords(['Message $i']);

        await NfcHce.addOrUpdateNdefFile(
            fileId: standardNdefFileId, records: records);

        expect(await NfcHce.hasFile(fileId: standardNdefFileId), true,
            reason: 'File should exist in iteration $i');
      }
    });

    testWidgets('HCE Transaction Stream test', (tester) async {
      // Set up a test record
      final records = TestHelper.createSimpleTextRecords(['Test Message']);
      await NfcHce.addOrUpdateNdefFile(
          fileId: standardNdefFileId, records: records);

      // Test that stream is available and accepting subscriptions
      final stream = NfcHce.stream;
      expect(stream, isNotNull);

      final subscription = stream.listen((transaction) {
        // Just verify that we can subscribe to the stream
        // In a real app, we would verify transaction data
        expect(transaction, isA<HceTransaction>());
      });

      // Clean up
      await subscription.cancel();
    });

    testWidgets('Multiple file management test', (tester) async {
      final fileIds = [0xE104, 0xE105, 0xE106];
      final records = TestHelper.createSimpleTextRecords(['File content']);

      // Create multiple files
      for (var fileId in fileIds) {
        await NfcHce.addOrUpdateNdefFile(
            fileId: fileId, records: records, maxFileSize: 1024);

        expect(await NfcHce.hasFile(fileId: fileId), true,
            reason: 'File $fileId should exist after creation');
      }

      // Delete specific file
      await NfcHce.deleteNdefFile(fileId: fileIds[1]);
      expect(await NfcHce.hasFile(fileId: fileIds[1]), false,
          reason: 'Deleted file should not exist');
      expect(await NfcHce.hasFile(fileId: fileIds[0]), true,
          reason: 'Other files should still exist');

      // Clear all files
      await NfcHce.clearAllFiles();
      for (var fileId in fileIds) {
        expect(await NfcHce.hasFile(fileId: fileId), false,
            reason: 'No files should exist after clearing');
      }
    });

    testWidgets('File size limit test', (tester) async {
      final smallRecords =
          TestHelper.createSimpleTextRecords(['Small content']);

      final largeContent = 'A' * 2100; // Content larger than default max size
      final largeRecords = TestHelper.createSimpleTextRecords([largeContent]);

      // Test with default size limit
      await NfcHce.addOrUpdateNdefFile(
          fileId: standardNdefFileId, records: smallRecords);

      // Test with large content - should fail with default size
      expect(
          () async => await NfcHce.addOrUpdateNdefFile(
              fileId: standardNdefFileId, records: largeRecords),
          throwsA(isA<HceException>()),
          reason: 'Should throw when content exceeds default size');

      // Test with increased size limit
      await NfcHce.addOrUpdateNdefFile(
          fileId: standardNdefFileId, records: largeRecords, maxFileSize: 4096);
    });

    testWidgets('Error handling test', (tester) async {
      // Test invalid NDEF record handling
      expect(
          () async => await NfcHce.addOrUpdateNdefFile(
              fileId: standardNdefFileId, records: []),
          throwsA(isA<HceException>()),
          reason: 'Should throw on empty records list');

      // Test invalid file ID
      expect(
          () async => await NfcHce.addOrUpdateNdefFile(
              fileId: 0x0000, // Invalid file ID
              records: TestHelper.createSimpleTextRecords(['Test'])),
          throwsA(isA<HceException>()),
          reason: 'Should throw on invalid file ID');

      // Test operations with uninitialized state
      await NfcHce.clearAllFiles();
      final newAid = Uint8List.fromList([0xF0, 0x01, 0x02, 0x03, 0x04]);

      // Re-initialize with different AID
      await NfcHce.init(aid: newAid);
      expect(await NfcHce.hasFile(fileId: standardNdefFileId), false,
          reason: 'Files should not persist across different AIDs');
    });
  });
}
