import 'dart:typed_data';

import '../../field.dart';
import '../fields/ndef_record_fields.dart';
import 'ndef_record_serializer.dart';

class NdefFormatException implements Exception {
  final String message;
  NdefFormatException(this.message);
  @override
  String toString() => 'NdefFormatException: $message';
}

enum _ChunkedRecordState { notInChunk, awaitingMiddleOrEndChunk }


class _NdefParser {
  final Uint8List _rawMessage;
  int _offset = 0;
  _ChunkedRecordState _chunkState = _ChunkedRecordState.notInChunk;
  BytesBuilder? _reassembledPayload;
  NdefTypeField? _reassembledType;
  NdefIdField? _reassembledId;
  bool _isFirstRecordInMessage = true;

  _NdefParser(this._rawMessage);

  List<NdefRecordSerializer> parse() {
    final completeRecords = <NdefRecordSerializer>[];
    while (_offset < _rawMessage.length) {
      final record = _parseNextRecord();
      if (record != null) {
        completeRecords.add(record);
      }
      if (record?.flags.isMessageEnd ?? false) break;
    }

    if (_chunkState == _ChunkedRecordState.awaitingMiddleOrEndChunk) {
      throw NdefFormatException('Invalid NDEF message: message ends with an incomplete chunk sequence.');
    }
    return completeRecords;
  }

  NdefRecordSerializer? _parseNextRecord() {
    final flags = _readFlags();
    final typeLength = _readTypeLength(flags);
    final (payloadLength, payloadLengthBytes) = _readPayloadLength(flags);
    final idLength = _readIdLength(flags);
    final type = _readType(flags, typeLength);
    final id = _readId(flags, idLength);
    final payload = _readPayload(payloadLength);

    return _processRecord(flags, type, payload, id);
  }

  NdefRecordSerializer? _processRecord(NdefFlagByte flags, NdefTypeField type, NdefPayload? payload, NdefIdField? id) {
    switch (_chunkState) {
      case _ChunkedRecordState.notInChunk:
        if (flags.isChunked) {
          _validateFirstChunk(flags);
          _chunkState = _ChunkedRecordState.awaitingMiddleOrEndChunk;
          _reassembledPayload = BytesBuilder(copy: false)..add(payload?.buffer ?? Uint8List(0));
          _reassembledType = type;
          _reassembledId = id;
          return null; 
        } else {
          final isLast = _offset >= _rawMessage.length;
          final record = NdefRecordSerializer.record(type: type, payload: payload, id: id, isFirstInMessage: _isFirstRecordInMessage, isLastInMessage: isLast);
          _isFirstRecordInMessage = false;
          return record;
        }
      case _ChunkedRecordState.awaitingMiddleOrEndChunk:
        _validateSubsequentChunk(flags);
        _reassembledPayload?.add(payload?.buffer ?? Uint8List(0));
        if (flags.isChunked) {
          return null;
        } else {
          _chunkState = _ChunkedRecordState.notInChunk;
          final finalPayload = NdefPayload(_reassembledPayload?.takeBytes() ?? Uint8List(0));
          final record = NdefRecordSerializer.record(type: _reassembledType!, payload: finalPayload, id: _reassembledId, isFirstInMessage: _isFirstRecordInMessage, isLastInMessage: flags.isMessageEnd);
          _isFirstRecordInMessage = false;
          return record;
        }
    }
  }

  NdefFlagByte _readFlags() {
    if (_offset >= _rawMessage.length) throw NdefFormatException("Unexpected end of data when reading flags.");
    return NdefFlagByte.fromByte(_rawMessage[_offset++]);
  }

  int _readTypeLength(NdefFlagByte flags) {
    if (flags.tnf == Tnf.empty || (_chunkState == _ChunkedRecordState.awaitingMiddleOrEndChunk && flags.tnf == Tnf.unchanged)) return 0;
    if (_offset >= _rawMessage.length) throw NdefFormatException("Unexpected end of data when reading type length.");
    return _rawMessage[_offset++];
  }

  (int, int) _readPayloadLength(NdefFlagByte flags) {
    if (flags.isShortRecord) {
      if (_offset >= _rawMessage.length) throw NdefFormatException("Unexpected end of data for short payload length.");
      return (_rawMessage[_offset++], 1);
    } else {
      if (_offset + 3 >= _rawMessage.length) throw NdefFormatException("Unexpected end of data for long payload length.");
      final length = ByteData.view(_rawMessage.buffer).getUint32(_offset, Endian.big);
      _offset += 4;
      return (length, 4);
    }
  }

  int _readIdLength(NdefFlagByte flags) {
    if (!flags.hasId) return 0;
    if (_chunkState == _ChunkedRecordState.awaitingMiddleOrEndChunk) throw NdefFormatException("Invalid chunk: ID length must only be present in the first chunk.");
    if (_offset >= _rawMessage.length) throw NdefFormatException("Unexpected end of data when reading ID length.");
    return _rawMessage[_offset++];
  }

  NdefTypeField _readType(NdefFlagByte flags, int length) {
    if (length == 0) return NdefTypeField(Uint8List(0), tnf: flags.tnf);
    if (_chunkState == _ChunkedRecordState.awaitingMiddleOrEndChunk) throw NdefFormatException("Invalid chunk: Type must only be present in the first chunk.");
    if (_offset + length > _rawMessage.length) throw NdefFormatException("Unexpected end of data when reading type.");
    final typeBytes = _rawMessage.sublist(_offset, _offset + length);
    _offset += length;
    return NdefTypeField(typeBytes, tnf: flags.tnf);
  }

  NdefIdField? _readId(NdefFlagByte flags, int length) {
    if (!flags.hasId || length == 0) return null;
    if (_offset + length > _rawMessage.length) throw NdefFormatException("Unexpected end of data when reading ID.");
    final idBytes = _rawMessage.sublist(_offset, _offset + length);
    _offset += length;
    return NdefIdField(idBytes);
  }
  
  NdefPayload? _readPayload(int length) {
    if (length == 0) return null;
    if (_offset + length > _rawMessage.length) throw NdefFormatException("Unexpected end of data when reading payload.");
    final payloadBytes = _rawMessage.sublist(_offset, _offset + length);
    _offset += length;
    return NdefPayload(payloadBytes);
  }

  void _validateFirstChunk(NdefFlagByte flags) {
    if (flags.tnf == Tnf.empty || flags.tnf == Tnf.unchanged) {
      throw NdefFormatException("Invalid first chunk: TNF cannot be Empty or Unchanged.");
    }
  }

  void _validateSubsequentChunk(NdefFlagByte flags) {
    if (flags.tnf != Tnf.unchanged) {
      throw NdefFormatException("Invalid subsequent chunk: TNF must be Unchanged.");
    }
    if (flags.hasId) {
      throw NdefFormatException("Invalid subsequent chunk: ID field is not allowed.");
    }
  }
}

class NdefMessageSerializer extends ApduSerializer {
  final List<NdefRecordSerializer> records;

  factory NdefMessageSerializer.fromBytes(Uint8List rawMessage) {
    if (rawMessage.isEmpty) {
      throw ArgumentError('Cannot parse an empty NDEF message.');
    }
    final parser = _NdefParser(rawMessage);
    final records = parser.parse();
    if (records.isEmpty) {
      throw ArgumentError('Failed to parse any valid records from the NDEF message.');
    }
    return NdefMessageSerializer._internal(records);
  }

  factory NdefMessageSerializer.fromRecords({
    required List<NdefRecordSerializer> records,
  }) {
    if (records.isEmpty) {
      throw ArgumentError('Cannot create an NDEF message with zero records.');
    }

    return NdefMessageSerializer._internal(records);
  }

  NdefMessageSerializer._internal(this.records) : super(name: "NDEF Message");

  @override
  void setFields() {
    fields = records;
  }
}