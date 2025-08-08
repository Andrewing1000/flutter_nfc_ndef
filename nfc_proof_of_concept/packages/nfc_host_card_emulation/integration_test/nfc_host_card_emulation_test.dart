import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('nfc_host_card_emulation');
  final Map<int, List<NdefRecordData>> mockFiles = {};

  // Register mock handler before any tests run
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'checkNfcState':
        return 'enabled';
      case 'init':
        mockFiles.clear(); // Clear files on init
        return true;
      case 'addOrUpdateFile':
        final Map<String, dynamic> args =
            call.arguments as Map<String, dynamic>;
        final int fileId = args['fileId'] as int;
        final List<dynamic> records = args['records'] as List<dynamic>;
        mockFiles[fileId] = records
            .map((r) => NdefRecordData(
                type: r['type'] as String,
                payload: Uint8List.fromList(
                    (r['payload'] as List<dynamic>).cast<int>())))
            .toList();
        return true;
      case 'deleteFile':
        final Map<String, dynamic> args =
            call.arguments as Map<String, dynamic>;
        final int fileId = args['fileId'] as int;
        mockFiles.remove(fileId);
        return true;
      case 'clearAllFiles':
        mockFiles.clear();
        return true;
      case 'hasFile':
        final Map<String, dynamic> args =
            call.arguments as Map<String, dynamic>;
        final int fileId = args['fileId'] as int;
        return mockFiles.containsKey(fileId);
      case 'getTransactionStream':
        // Simulate a transaction after a short delay
        Future.delayed(Duration(seconds: 1), () {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .handlePlatformMessage(
                  'nfc_host_card_emulation_event',
                  const StandardMethodCodec().encodeSuccessEnvelope({
                    'type': 'transaction',
                    'fileId': 0xE104,
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                  }),
                  (ByteData? data) {});
        });
        return null;
      default:
        throw MissingPluginException();
    }
  });

  group('NFC Host Card Emulation Integration Tests', () {
    late NfcState nfcState;

    setUpAll(() {
      // Set up method channel mocks
      const channel = MethodChannel('nfc_host_card_emulation');

      // Keep track of files in memory for testing
      final Map<int, List<NdefRecordData>> mockFiles = {};

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'checkNfcState':
            return 'enabled';
          case 'init':
            mockFiles.clear(); // Clear files on init
            return true;
          case 'addOrUpdateFile':
            final Map<String, dynamic> args =
                call.arguments as Map<String, dynamic>;
            final int fileId = args['fileId'] as int;
            final List<dynamic> records = args['records'] as List<dynamic>;
            mockFiles[fileId] = records
                .map((r) => NdefRecordData(
                    type: r['type'] as String,
                    payload: Uint8List.fromList(
                        (r['payload'] as List<dynamic>).cast<int>())))
                .toList();
            return true;
          case 'deleteFile':
            final Map<String, dynamic> args =
                call.arguments as Map<String, dynamic>;
            final int fileId = args['fileId'] as int;
            mockFiles.remove(fileId);
            return true;
          case 'clearAllFiles':
            mockFiles.clear();
            return true;
          case 'hasFile':
            final Map<String, dynamic> args =
                call.arguments as Map<String, dynamic>;
            final int fileId = args['fileId'] as int;
            return mockFiles.containsKey(fileId);
          case 'getTransactionStream':
            // Simulate a transaction after a short delay
            Future.delayed(Duration(seconds: 1), () {
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                  .handlePlatformMessage(
                      'nfc_host_card_emulation_event',
                      const StandardMethodCodec().encodeSuccessEnvelope({
                        'type': 'transaction',
                        'fileId': 0xE104,
                        'timestamp': DateTime.now().millisecondsSinceEpoch,
                      }),
                      (ByteData? data) {});
            });
            return null;
          default:
            return null;
        }
      });
    });

    setUpAll(() async {
      nfcState = await NfcHce.checkDeviceNfcState();
      if (nfcState != NfcState.enabled) {
        fail('These tests require NFC to be enabled on the device');
      }
    });

    test('Full NDEF workflow', () async {
      // Initialize HCE
      final aid =
          Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);
      await NfcHce.init(aid: aid);

      // Create a text record
      final textRecord = NdefRecordData(
          type: 'text/plain',
          payload: Uint8List.fromList('Hello, NFC World!'.codeUnits));

      // Create a URL record
      final urlRecord = NdefRecordData(
          type: 'U',
          payload: Uint8List.fromList('https://example.com'.codeUnits));

      // Add multiple records to a file
      await NfcHce.addOrUpdateNdefFile(
          fileId: 0xE104,
          records: [textRecord, urlRecord],
          maxFileSize: 4096,
          isWritable: true);

      // Verify file exists
      expect(await NfcHce.hasFile(fileId: 0xE104), true);

      // Listen for NFC transactions
      final transactions = <HceTransaction>[];
      final subscription = NfcHce.stream.listen((transaction) {
        transactions.add(transaction);
      });

      // Wait a bit to potentially capture some transactions
      await Future.delayed(const Duration(seconds: 5));

      // Clean up
      await subscription.cancel();
      await NfcHce.clearAllFiles();

      // Verify cleanup
      expect(await NfcHce.hasFile(fileId: 0xE104), false);
    });

    test('Multiple file handling', () async {
      final aid =
          Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);
      await NfcHce.init(aid: aid);

      // Create multiple files with different content
      final files = <int, List<NdefRecordData>>{
        0xE104: [
          NdefRecordData(
              type: 'text/plain',
              payload: Uint8List.fromList('File 1'.codeUnits))
        ],
        0xE105: [
          NdefRecordData(
              type: 'text/plain',
              payload: Uint8List.fromList('File 2'.codeUnits))
        ],
        0xE106: [
          NdefRecordData(
              type: 'text/plain',
              payload: Uint8List.fromList('File 3'.codeUnits))
        ]
      };

      // Add all files
      for (final entry in files.entries) {
        await NfcHce.addOrUpdateNdefFile(
            fileId: entry.key, records: entry.value);
      }

      // Verify all files exist
      for (final fileId in files.keys) {
        expect(await NfcHce.hasFile(fileId: fileId), true,
            reason: 'File 0x${fileId.toRadixString(16)} should exist');
      }

      // Delete files one by one
      for (final fileId in files.keys) {
        await NfcHce.deleteNdefFile(fileId: fileId);
        expect(await NfcHce.hasFile(fileId: fileId), false,
            reason: 'File 0x${fileId.toRadixString(16)} should be deleted');
      }
    });

    test('State management', () async {
      final aid =
          Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);
      await NfcHce.init(aid: aid);

      // Add a file
      await NfcHce.addOrUpdateNdefFile(fileId: 0xE104, records: [
        NdefRecordData(
            type: 'text/plain', payload: Uint8List.fromList('Test'.codeUnits))
      ]);

      // Verify initial state
      expect(await NfcHce.hasFile(fileId: 0xE104), true);

      // Clear all files
      await NfcHce.clearAllFiles();
      expect(await NfcHce.hasFile(fileId: 0xE104), false);

      // Re-add the file
      await NfcHce.addOrUpdateNdefFile(fileId: 0xE104, records: [
        NdefRecordData(
            type: 'text/plain', payload: Uint8List.fromList('Test 2'.codeUnits))
      ]);
      expect(await NfcHce.hasFile(fileId: 0xE104), true);

      // Delete specific file
      await NfcHce.deleteNdefFile(fileId: 0xE104);
      expect(await NfcHce.hasFile(fileId: 0xE104), false);
    });
  });
}
