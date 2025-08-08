import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_host_card_emulation/app_layer/errors.dart';
import 'package:nfc_host_card_emulation/app_layer/validation.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNfcHostCardEmulationPlatform
    with MockPlatformInterfaceMixin
    implements NfcHostCardEmulationPlatform {
  bool initialized = false;
  final Map<int, List<NdefRecordData>> files = {};

  @override
  Future<void> init({required Uint8List aid}) async {
    if (aid.length < 5 || aid.length > 16) {
      throw HceException(
          HceErrorCode.invalidAid, "AID length must be between 5 and 16 bytes");
    }
    initialized = true;
  }

  @override
  Stream<HceTransaction> get transactionStream =>
      Stream.empty(); // Mock stream for testing

  @override
  Future<void> addOrUpdateNdefFile({
    required int fileId,
    required List<NdefRecordData> records,
    int maxFileSize = 2048,
    bool isWritable = false,
  }) async {
    if (!initialized) {
      throw HceException(HceErrorCode.invalidState, "Not initialized");
    }
    ValidationUtils.validateFileId(fileId);
    if (records.isEmpty) {
      throw HceException(HceErrorCode.invalidNdefFormat, "Empty records list");
    }

    // Calculate total size of all records
    int totalSize = 0;
    for (var record in records) {
      totalSize += record.payload.length;
      if (record.type.isNotEmpty) {
        totalSize += record.type.length;
      }
    }

    // Add overhead for NDEF record headers and TLV structure
    totalSize += records.length * 6; // Approximate header size per record
    totalSize += 4; // TLV overhead

    if (totalSize > maxFileSize) {
      throw HceException(HceErrorCode.messageTooLarge,
          "Message size ($totalSize bytes) exceeds maximum file size ($maxFileSize bytes)");
    }

    files[fileId] = List.from(records);
  }

  @override
  Future<void> deleteNdefFile({required int fileId}) async {
    if (!initialized) {
      throw HceException(HceErrorCode.invalidState, "Not initialized");
    }
    if (!files.containsKey(fileId)) {
      throw HceException(HceErrorCode.fileNotFound, "File not found");
    }
    files.remove(fileId);
  }

  @override
  Future<void> clearAllFiles() async {
    if (!initialized) {
      throw HceException(HceErrorCode.invalidState, "Not initialized");
    }
    files.clear();
  }

  @override
  Future<bool> hasFile({required int fileId}) async {
    if (!initialized) {
      throw HceException(HceErrorCode.invalidState, "Not initialized");
    }
    return files.containsKey(fileId);
  }

  @override
  Future<NfcState> checkDeviceNfcState() async {
    return NfcState.enabled;
  }

  @override
  Future<void> dispose() async {
    initialized = false;
    files.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NFC Host Card Emulation', () {
    late MockNfcHostCardEmulationPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockNfcHostCardEmulationPlatform();
      NfcHostCardEmulationPlatform.instance = mockPlatform;
    });

    test('initializes with valid AID', () async {
      final aid =
          Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);
      await NfcHce.init(aid: aid);
      expect(mockPlatform.initialized, true);
    });

    test('fails initialization with invalid AID', () async {
      final aid = Uint8List.fromList([0x01, 0x02]); // Too short
      expect(
          () => NfcHce.init(aid: aid),
          throwsA(predicate(
              (e) => e is HceException && e.code == HceErrorCode.invalidAid)));
    });

    group('NDEF File Management', () {
      setUp(() async {
        final aid =
            Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);
        await NfcHce.init(aid: aid);
      });

      test('adds NDEF file with valid data', () async {
        final records = [
          NdefRecordData(
              type: 'text/plain',
              payload:
                  Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]) // "Hello"
              )
        ];

        await NfcHce.addOrUpdateNdefFile(fileId: 0xE104, records: records);

        expect(await NfcHce.hasFile(fileId: 0xE104), true);
      });

      test('fails to add file with invalid ID', () async {
        final records = [
          NdefRecordData(
              type: 'text/plain',
              payload: Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]))
        ];

        expect(
            () => NfcHce.addOrUpdateNdefFile(
                fileId: 0x3F00, // Reserved ID
                records: records),
            throwsA(predicate((e) =>
                e is HceException && e.code == HceErrorCode.invalidFileId)));
      });

      test('updates existing file', () async {
        final records1 = [
          NdefRecordData(
              type: 'text/plain',
              payload: Uint8List.fromList([0x48, 0x69]) // "Hi"
              )
        ];

        final records2 = [
          NdefRecordData(
              type: 'text/plain',
              payload: Uint8List.fromList([0x42, 0x79, 0x65]) // "Bye"
              )
        ];

        await NfcHce.addOrUpdateNdefFile(fileId: 0xE104, records: records1);
        await NfcHce.addOrUpdateNdefFile(fileId: 0xE104, records: records2);

        expect(await NfcHce.hasFile(fileId: 0xE104), true);
        expect(mockPlatform.files[0xE104], equals(records2));
      });

      test('deletes existing file', () async {
        final records = [
          NdefRecordData(
              type: 'text/plain', payload: Uint8List.fromList([0x48, 0x69]))
        ];

        await NfcHce.addOrUpdateNdefFile(fileId: 0xE104, records: records);
        await NfcHce.deleteNdefFile(fileId: 0xE104);

        expect(await NfcHce.hasFile(fileId: 0xE104), false);
      });

      test('fails to delete non-existent file', () async {
        expect(
            () => NfcHce.deleteNdefFile(fileId: 0xE105),
            throwsA(predicate((e) =>
                e is HceException && e.code == HceErrorCode.fileNotFound)));
      });

      test('clears all files', () async {
        final records = [
          NdefRecordData(
              type: 'text/plain', payload: Uint8List.fromList([0x48, 0x69]))
        ];

        await NfcHce.addOrUpdateNdefFile(fileId: 0xE104, records: records);
        await NfcHce.addOrUpdateNdefFile(fileId: 0xE105, records: records);

        await NfcHce.clearAllFiles();

        expect(await NfcHce.hasFile(fileId: 0xE104), false);
        expect(await NfcHce.hasFile(fileId: 0xE105), false);
      });

      test('checks NFC state', () async {
        final state = await NfcHce.checkDeviceNfcState();
        expect(state, NfcState.enabled);
      });
    });

    group('NDEF Record Validation', () {
      setUp(() async {
        final aid =
            Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);
        await NfcHce.init(aid: aid);
      });

      test('fails with empty records list', () async {
        expect(
            () => NfcHce.addOrUpdateNdefFile(fileId: 0xE104, records: []),
            throwsA(predicate((e) =>
                e is HceException &&
                e.code == HceErrorCode.invalidNdefFormat)));
      });

      test('fails with oversized payload', () async {
        final oversizedPayload = Uint8List(70000); // Exceeds max size
        final records = [
          NdefRecordData(type: 'text/plain', payload: oversizedPayload)
        ];

        expect(
            () => NfcHce.addOrUpdateNdefFile(
                fileId: 0xE104, records: records, maxFileSize: 2048),
            throwsA(predicate((e) =>
                e is HceException && e.code == HceErrorCode.messageTooLarge)));
      });
    });
  });
}
