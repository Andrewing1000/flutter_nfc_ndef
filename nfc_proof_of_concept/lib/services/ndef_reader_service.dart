import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:flutter_hce/app_layer/utils/apdu_command_parser.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_message_serializer.dart';

class NdefReaderService {
  final Uint8List aid;
  static const int _defaultChunkSize = 240;
  NdefReaderService({required this.aid});

  Future<Map<String, dynamic>?> readNdefFromTag(NfcTag tag) async {
    final isoDep = IsoDep.from(tag);
    if (isoDep == null) {
      debugPrint('Tag is not ISO-DEP compatible (Type 4)');
      return null;
    }

    try {
      debugPrint('Connected to ISO-DEP tag');

      if (!await _selectNdefApplication(isoDep)) {
        return null;
      }

      if (!await _selectCapabilityContainer(isoDep)) {
        return null;
      }

      if (!await _readCapabilityContainer(isoDep)) {
        return null;
      }

      if (!await _selectNdefFile(isoDep)) {
        return null;
      }

      final ndefLength = await _readNdefLength(isoDep);
      if (ndefLength == null) {
        return null;
      }

      if (ndefLength == 0) {
        debugPrint('NDEF file is empty');
        return {'empty': true};
      }

      final ndefDataBytes = await _readNdefData(isoDep, ndefLength);
      if (ndefDataBytes == null) {
        return null;
      }

      return _parseNdefData(Uint8List.fromList(ndefDataBytes));
    } finally {
      debugPrint('Tag session complete');
    }
  }

  Future<bool> _selectNdefApplication(IsoDep isoDep) async {
    final selectAppCommand = ApduCommandParser.selectByName(
      applicationId: aid,
    );

    final response = await isoDep.transceive(data: selectAppCommand.toBytes());
    if (!_isSuccessResponse(response)) {
      debugPrint(
          'Failed to select NDEF application: ${_formatBytes(response)}');
      return false;
    }

    debugPrint('NDEF application selected');
    return true;
  }

  Future<bool> _selectCapabilityContainer(IsoDep isoDep) async {
    final selectCcCommand = ApduCommandParser.selectCapabilityContainer();
    final response = await isoDep.transceive(data: selectCcCommand.toBytes());

    if (!_isSuccessResponse(response)) {
      debugPrint('Failed to select CC file: ${_formatBytes(response)}');
      return false;
    }

    debugPrint('CC file selected');
    return true;
  }

  Future<bool> _readCapabilityContainer(IsoDep isoDep) async {
    final readCcCommand = ApduCommandParser.readCapabilityContainer();
    final response = await isoDep.transceive(data: readCcCommand.toBytes());

    if (!_isSuccessResponse(response)) {
      debugPrint('Failed to read CC file: ${_formatBytes(response)}');
      return false;
    }

    debugPrint('CC file read: ${_formatBytes(response)}');
    return true;
  }

  Future<bool> _selectNdefFile(IsoDep isoDep) async {
    final selectNdefCommand = ApduCommandParser.selectNdefFile();
    final response = await isoDep.transceive(data: selectNdefCommand.toBytes());

    if (!_isSuccessResponse(response)) {
      debugPrint('Failed to select NDEF file: ${_formatBytes(response)}');
      return false;
    }

    debugPrint('NDEF file selected');
    return true;
  }

  Future<int?> _readNdefLength(IsoDep isoDep) async {
    final readLengthCommand = ApduCommandParser.readNdefLength();
    final response = await isoDep.transceive(data: readLengthCommand.toBytes());

    if (!_isSuccessResponse(response)) {
      debugPrint('Failed to read NDEF length: ${_formatBytes(response)}');
      return null;
    }

    final ndefLength = (response[0] << 8) + response[1];
    debugPrint('NDEF data length: $ndefLength bytes');
    return ndefLength;
  }

  Future<List<int>?> _readNdefData(IsoDep isoDep, int ndefLength) async {
    final ndefDataBytes = <int>[];
    int offset = 2;

    while (offset < ndefLength + 2) {
      final remaining = (ndefLength + 2) - offset;
      final toRead =
          remaining > _defaultChunkSize ? _defaultChunkSize : remaining;

      final readChunkCommand = ApduCommandParser.readChunk(
        offset: offset,
        chunkSize: toRead,
      );

      final chunkData =
          await isoDep.transceive(data: readChunkCommand.toBytes());
      if (!_isSuccessResponse(chunkData)) {
        debugPrint(
            'Failed to read NDEF chunk at offset $offset: ${_formatBytes(chunkData)}');
        return null;
      }

      ndefDataBytes.addAll(chunkData.sublist(0, chunkData.length - 2));
      offset += toRead;

      debugPrint('Read chunk: offset=$offset, size=${chunkData.length - 2}');
    }

    debugPrint('NDEF data read complete: ${ndefDataBytes.length} bytes');
    return ndefDataBytes;
  }

  Map<String, dynamic>? _parseNdefData(Uint8List ndefBytes) {
    if (ndefBytes.isEmpty) {
      debugPrint('NDEF data is empty');
      return null;
    }

    try {
      debugPrint(
          'Parsing NDEF data using proper NDEF message serializer: ${_formatBytes(ndefBytes)}');

      // Use the proper NDEF message serializer to parse records
      final ndefMessage = NdefMessageSerializer.fromBytes(ndefBytes);
      final mergedData = <String, dynamic>{};

      debugPrint('Found ${ndefMessage.records.length} NDEF records');

      // Process each record and merge JSON-parseable data
      for (final record in ndefMessage.records) {
        final recordData = _extractJsonDataFromRecord(record);
        if (recordData != null) {
          debugPrint('Found JSON-parseable record: ${recordData.keys}');
          mergedData.addAll(recordData);
        } else {
          debugPrint('Skipped non-JSON record with type: ${record.type.tnf}');
        }
      }

      if (mergedData.isEmpty) {
        debugPrint('No JSON-parseable records found in NDEF message');
        return null;
      }

      debugPrint('Merged JSON data: $mergedData');
      return mergedData;
    } catch (e) {
      debugPrint('Error parsing NDEF data with proper serializer: $e');
      return null;
    }
  }

  Map<String, dynamic>? _extractJsonDataFromRecord(dynamic record) {
    try {
      // Use the convenient getter methods from NdefRecordSerializer

      // First priority: Direct JSON records
      final jsonData = record.jsonContent;
      if (jsonData != null) {
        debugPrint('Found JSON record: $jsonData');
        return jsonData;
      }

      // Second priority: Text records that might contain JSON
      final textData = record.textContent;
      if (textData != null) {
        try {
          final parsedJson = json.decode(textData);
          if (parsedJson is Map<String, dynamic>) {
            debugPrint('Found JSON in text record: $parsedJson');
            return parsedJson;
          }
        } catch (_) {
          // Not valid JSON, ignore
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting JSON from NDEF record: $e');
      return null;
    }
  }

  bool _isSuccessResponse(Uint8List response) {
    return response.length >= 2 &&
        response[response.length - 2] == 0x90 &&
        response[response.length - 1] == 0x00;
  }

  String _formatBytes(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }
}
