import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:flutter_hce/app_layer/utils/apdu_command_parser.dart';

class NdefReaderService {
  static const List<int> _ndefApplicationId = [
    0xD2,
    0x76,
    0x00,
    0x00,
    0x85,
    0x01,
    0x01
  ];

  static const int _defaultChunkSize = 240;

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
      applicationId: _ndefApplicationId,
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
      return {'empty': true};
    }

    try {
      debugPrint('Parsing NDEF data: ${_formatBytes(ndefBytes)}');

      final result = <String, dynamic>{
        'rawData': _formatBytes(ndefBytes),
        'length': ndefBytes.length,
        'records': <Map<String, dynamic>>[]
      };

      int offset = 0;
      while (offset < ndefBytes.length) {
        if (offset + 3 >= ndefBytes.length) break;

        final flags = ndefBytes[offset];
        final typeLength = ndefBytes[offset + 1];
        final payloadLength = ndefBytes[offset + 2];

        if (offset + 3 + typeLength + payloadLength > ndefBytes.length) break;

        final payload = ndefBytes.sublist(
            offset + 3 + typeLength, offset + 3 + typeLength + payloadLength);

        _parseNdefRecord(payload, result);

        offset += 3 + typeLength + payloadLength;

        if ((flags & 0x80) != 0 && (flags & 0x40) != 0) break;
      }

      debugPrint('Parsed ${result['records'].length} NDEF records');
      return result;
    } catch (e) {
      debugPrint('Error parsing NDEF data: $e');
      return {
        'error': 'Failed to parse NDEF data: $e',
        'rawData': _formatBytes(ndefBytes)
      };
    }
  }

  void _parseNdefRecord(Uint8List payload, Map<String, dynamic> result) {
    try {
      final decodedPayload = utf8.decode(payload);
      try {
        final jsonData = json.decode(decodedPayload);
        result['records'].add({
          'type': 'application/json',
          'data': jsonData,
          'raw': decodedPayload
        });
      } catch (e) {
        result['records'].add({
          'type': 'text/plain',
          'data': decodedPayload,
        });
      }
    } catch (e) {
      result['records'].add({
        'type': 'application/octet-stream',
        'data': payload,
      });
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
