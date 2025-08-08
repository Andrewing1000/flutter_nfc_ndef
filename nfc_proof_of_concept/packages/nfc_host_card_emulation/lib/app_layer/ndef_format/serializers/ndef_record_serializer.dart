import 'dart:typed_data';

import '../../field.dart';
import '../fields/ndef_record_fields.dart';

class NdefRecordSerializer extends ApduSerializer {
  final NdefFlagByte flags;
  final NdefTypeLengthField typeLength;
  final NdefPayloadLengthField payloadLength;
  final NdefIdLengthField? idLength;

  final NdefTypeField type;
  final NdefIdField? id;
  final NdefPayload? payload;

  NdefRecordSerializer._internal({
    required this.flags,
    required this.type,
    this.payload,
    this.id,
  })  : typeLength = NdefTypeLengthField(type.length),
        payloadLength = NdefPayloadLengthField(payload?.length ?? 0),
        idLength = (id != null) ? NdefIdLengthField(id.length) : null,
        super(name: "NDEF Record");

  factory NdefRecordSerializer.record({
    required NdefTypeField type,
    NdefPayload? payload,
    NdefIdField? id,
    bool isFirstInMessage = true,
    bool isLastInMessage = true,
  }) {
    _validateRecordArgs(type, payload, id);

    final payloadLen = payload?.length ?? 0;
    final isShortRecord = payloadLen < 256;
    final hasId = id != null;

    final flags = NdefFlagByte.record(
      tnf: type.tnf,
      isShortRecord: isShortRecord,
      hasId: hasId,
      isFirst: isFirstInMessage,
      isLast: isLastInMessage,
    );

    return NdefRecordSerializer._internal(
      flags: flags,
      type: type,
      payload: payload,
      id: id,
    );
  }

  factory NdefRecordSerializer.fromBytes(Uint8List rawRecord, {int initialOffset = 0}) {
    var offset = initialOffset;
    if (offset >= rawRecord.length) {
      throw ArgumentError('Malformed NDEF: Buffer too short for flags.');
    }

    final flags = NdefFlagByte.fromByte(rawRecord[offset++]);

    if (offset >= rawRecord.length) {
      throw ArgumentError('Malformed NDEF: Not enough bytes for type length.');
    }
    final typeLength = rawRecord[offset++];
    
    int payloadLength;
    if (flags.isShortRecord) {
      if (offset >= rawRecord.length) throw ArgumentError('Malformed NDEF: Not enough bytes for short payload length.');
      payloadLength = rawRecord[offset++];
    } else {
      if (offset + 3 >= rawRecord.length) throw ArgumentError('Malformed NDEF: Not enough bytes for long payload length.');
      payloadLength = ByteData.view(rawRecord.buffer).getUint32(offset, Endian.big);
      offset += 4;
    }

    final idLength = flags.hasId ? rawRecord[offset++] : 0;

    if (offset + typeLength > rawRecord.length) throw ArgumentError('Malformed NDEF: Not enough bytes for type.');
    final typeBytes = rawRecord.sublist(offset, offset + typeLength);
    offset += typeLength;
    final type = NdefTypeField(typeBytes, tnf: flags.tnf);

    NdefIdField? id;
    if (idLength > 0) {
      if (offset + idLength > rawRecord.length) throw ArgumentError('Malformed NDEF: Not enough bytes for ID.');
      final idBytes = rawRecord.sublist(offset, offset + idLength);
      offset += idLength;
      id = NdefIdField(idBytes);
    }
    
    if (offset + payloadLength > rawRecord.length) throw ArgumentError('Malformed NDEF: Not enough bytes for payload.');
    final payloadBytes = rawRecord.sublist(offset, offset + payloadLength);
    final payload = NdefPayload(payloadBytes);

    return NdefRecordSerializer._internal(flags: flags, type: type, payload: payload, id: id);
  }

  factory NdefRecordSerializer.chunkBegin({
    required NdefTypeField type,
    required NdefPayload firstChunkPayload,
    NdefIdField? id,
    bool isFirstInMessage = true,
  }) {
    _validateChunkBeginArgs(type);
    final hasId = id != null;

    final flags = NdefFlagByte.chunk(
      tnf: type.tnf,
      isFirstChunk: true,
      isFirstMessageRecord: isFirstInMessage,
      hasId: hasId,
    );

    return NdefRecordSerializer._internal(
      flags: flags,
      type: type,
      payload: firstChunkPayload,
      id: id,
    );
  }

  factory NdefRecordSerializer.chunkIntermediate({
    required NdefPayload intermediateChunkPayload,
  }) {
    final flags = NdefFlagByte.chunk(isFirstChunk: false, isLastChunk: false);
    return NdefRecordSerializer._internal(
      flags: flags,
      type: NdefTypeField.unchanged,
      payload: intermediateChunkPayload,
    );
  }

  factory NdefRecordSerializer.chunkEnd({
    required NdefPayload lastChunkPayload,
    bool isLastInMessage = true,
  }) {
    final flags = NdefFlagByte.chunk(
      isFirstChunk: false,
      isLastChunk: true,
      isLastMessageRecord: isLastInMessage,
    );
    return NdefRecordSerializer._internal(
      flags: flags,
      type: NdefTypeField.unchanged,
      payload: lastChunkPayload,
    );
  }

  static void _validateRecordArgs(NdefTypeField type, NdefPayload? payload, NdefIdField? id) {
    final tnf = type.tnf;
    if (tnf == Tnf.empty && (type.length > 0 || (payload?.length ?? 0) > 0 || id != null)) {
      throw ArgumentError('Empty TNF record must have no type, payload, or id.');
    }
    if (tnf == Tnf.unchanged) {
      throw ArgumentError('Unchanged TNF is only for chunked records. Use chunk factories.');
    }
    if (tnf == Tnf.unknown && type.length > 0) {
      throw ArgumentError('Unknown TNF must not have a Type field.');
    }
  }

  static void _validateChunkBeginArgs(NdefTypeField type) {
    final tnf = type.tnf;
    if (tnf == Tnf.empty || tnf == Tnf.unchanged || tnf == Tnf.unknown) {
      throw ArgumentError('Invalid TNF for a starting chunk. Must be WKT, Media, URI, or External.');
    }
  }

  @override
  void setFields() {
    // With the new serializer, we just add fields based on their logical presence.
    // The base class serializer will handle nulls.
    fields = [
      flags,
      typeLength,
      payloadLength,
      flags.hasId ? idLength : null,
      type.length > 0 ? type : null,
      flags.hasId ? id : null,
      (payload?.length ?? 0) > 0 ? payload : null,
    ];
  }
}