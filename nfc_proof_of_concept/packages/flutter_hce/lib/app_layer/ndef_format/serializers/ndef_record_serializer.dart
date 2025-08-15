import 'dart:typed_data';
import 'dart:convert';

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

  // Single source of truth for URI scheme ↔ code mappings (order matters for prefix matching)
  static const Map<String, int> _uriSchemesToCode = {
    'http://www.': 0x01,
    'https://www.': 0x02,
    'http://': 0x03,
    'https://': 0x04,
    'tel:': 0x05,
    'mailto:': 0x06,
    'ftp://anonymous:anonymous@': 0x07,
    'ftp://ftp.': 0x08,
    'ftps://': 0x09,
    'sftp://': 0x0A,
    'smb://': 0x0B,
    'nfs://': 0x0C,
    'ftp://': 0x0D,
    'dav://': 0x0E,
    'news:': 0x0F,
    'telnet://': 0x10,
    'imap:': 0x11,
    'rtsp://': 0x12,
    'urn:': 0x13,
    'pop:': 0x14,
    'sip:': 0x15,
    'sips:': 0x16,
    'tftp:': 0x17,
    'btspp://': 0x18,
    'btl2cap://': 0x19,
    'btgoep://': 0x1A,
    'tcpobex://': 0x1B,
    'irdaobex://': 0x1C,
    'file://': 0x1D,
    'urn:epc:id:': 0x1E,
    'urn:epc:tag:': 0x1F,
    'urn:epc:pat:': 0x20,
    'urn:epc:raw:': 0x21,
    'urn:epc:': 0x22,
    'urn:nfc:': 0x23,
  };

  static final Map<int, String> _codeToUriScheme = {
    for (final e in _uriSchemesToCode.entries) e.value: e.key
  };

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

  /// Factory for creating NDEF Text records using WKT Text format
  /// Automatically creates the proper text payload with language code
  factory NdefRecordSerializer.text(
    String text,
    String language, {
    NdefIdField? id,
    bool isFirstInMessage = true,
    bool isLastInMessage = true,
  }) {
    // Create WKT Text payload format: [language_length][language][text]
    final languageBytes = Uint8List.fromList(utf8.encode(language));
    final textBytes = Uint8List.fromList(utf8.encode(text));
    final flags =
        languageBytes.length; // Text flags byte (just language length for now)

    final payloadData = Uint8List(1 + languageBytes.length + textBytes.length);
    payloadData[0] = flags;
    payloadData.setRange(1, 1 + languageBytes.length, languageBytes);
    payloadData.setRange(
        1 + languageBytes.length, payloadData.length, textBytes);

    final payload = NdefPayload(payloadData);

    return NdefRecordSerializer.record(
      type: NdefTypeField.text,
      payload: payload,
      id: id,
      isFirstInMessage: isFirstInMessage,
      isLastInMessage: isLastInMessage,
    );
  }

  /// Factory for creating NDEF URI records using WKT URI format
  /// Automatically handles URI identifier codes for common schemes
  factory NdefRecordSerializer.uri(
    String uri, {
    NdefIdField? id,
    bool isFirstInMessage = true,
    bool isLastInMessage = true,
  }) {
    // WKT URI payload format: [identifier_code][uri_field]
    int identifierCode = _getUriIdentifierCode(uri);
    String uriField = _getUriField(uri, identifierCode);

    final uriFieldBytes = Uint8List.fromList(utf8.encode(uriField));
    final payloadData = Uint8List(1 + uriFieldBytes.length);
    payloadData[0] = identifierCode;
    payloadData.setRange(1, payloadData.length, uriFieldBytes);

    final payload = NdefPayload(payloadData);

    return NdefRecordSerializer.record(
      type: NdefTypeField.uri,
      payload: payload,
      id: id,
      isFirstInMessage: isFirstInMessage,
      isLastInMessage: isLastInMessage,
    );
  }

  /// Factory for creating JSON records using Media Type format
  /// Uses "text/json" MIME type
  factory NdefRecordSerializer.json(
    Map<String, dynamic> jsonData, {
    NdefIdField? id,
    bool isFirstInMessage = true,
    bool isLastInMessage = true,
  }) {
    final jsonString = jsonEncode(jsonData);
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
    final payload = NdefPayload(jsonBytes);

    return NdefRecordSerializer.record(
      type: NdefTypeField.textJson,
      payload: payload,
      id: id,
      isFirstInMessage: isFirstInMessage,
      isLastInMessage: isLastInMessage,
    );
  }

  factory NdefRecordSerializer.fromBytes(Uint8List rawRecord,
      {int initialOffset = 0}) {
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
      if (offset >= rawRecord.length)
        throw ArgumentError(
            'Malformed NDEF: Not enough bytes for short payload length.');
      payloadLength = rawRecord[offset++];
    } else {
      if (offset + 3 >= rawRecord.length)
        throw ArgumentError(
            'Malformed NDEF: Not enough bytes for long payload length.');
      payloadLength =
          ByteData.view(rawRecord.buffer).getUint32(offset, Endian.big);
      offset += 4;
    }

    final idLength = flags.hasId ? rawRecord[offset++] : 0;

    // Extract type bytes and create strongly typed NdefTypeField
    NdefTypeField type;
    if (typeLength > 0) {
      if (offset + typeLength > rawRecord.length)
        throw ArgumentError('Malformed NDEF: Not enough bytes for type.');
      final typeBytes = rawRecord.sublist(offset, offset + typeLength);
      offset += typeLength;

      // Delegate to NdefTypeField smart constructor
      type = NdefTypeField(typeBytes, tnf: flags.tnf);
    } else {
      // Handle empty, unknown, or unchanged TNF types
      type = NdefTypeField(Uint8List(0), tnf: flags.tnf);
    }

    NdefIdField? id;
    if (idLength > 0) {
      if (offset + idLength > rawRecord.length)
        throw ArgumentError('Malformed NDEF: Not enough bytes for ID.');
      final idBytes = rawRecord.sublist(offset, offset + idLength);
      offset += idLength;
      id = NdefIdField(idBytes);
    }

    NdefPayload? payload;
    if (payloadLength > 0) {
      if (offset + payloadLength > rawRecord.length)
        throw ArgumentError('Malformed NDEF: Not enough bytes for payload.');
      final payloadBytes = rawRecord.sublist(offset, offset + payloadLength);
      payload = NdefPayload(payloadBytes);
    }

    return NdefRecordSerializer._internal(
        flags: flags, type: type, payload: payload, id: id);
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

  static void _validateRecordArgs(
      NdefTypeField type, NdefPayload? payload, NdefIdField? id) {
    final tnf = type.tnf;
    if (tnf == Tnf.empty &&
        (type.length > 0 || (payload?.length ?? 0) > 0 || id != null)) {
      throw ArgumentError(
          'Empty TNF record must have no type, payload, or id.');
    }
    if (tnf == Tnf.unchanged) {
      throw ArgumentError(
          'Unchanged TNF is only for chunked records. Use chunk factories.');
    }
    if (tnf == Tnf.unknown && type.length > 0) {
      throw ArgumentError('Unknown TNF must not have a Type field.');
    }
  }

  static void _validateChunkBeginArgs(NdefTypeField type) {
    final tnf = type.tnf;
    if (tnf == Tnf.empty || tnf == Tnf.unchanged || tnf == Tnf.unknown) {
      throw ArgumentError(
          'Invalid TNF for a starting chunk. Must be WKT, Media, URI, or External.');
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

  /// Helper method to get URI identifier code for common schemes
  static int _getUriIdentifierCode(String uri) {
    for (final entry in _uriSchemesToCode.entries) {
      if (uri.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return 0x00; // No abbreviation
  }

  /// Helper method to get URI field after removing abbreviated scheme
  static String _getUriField(String uri, int identifierCode) {
    if (identifierCode == 0x00) {
      return uri; // No abbreviation, return full URI
    }

    final scheme = _codeToUriScheme[identifierCode];
    if (scheme != null && uri.startsWith(scheme)) {
      return uri.substring(scheme.length);
    }
    return uri; // Fallback to full URI
  }

  // Convenience methods for accessing typed record data

  /// Returns the text content if this is a WKT Text record
  String? get textContent {
    if (type != NdefTypeField.text || payload == null) return null;

    try {
      final payloadBytes = payload!.buffer;
      if (payloadBytes.isEmpty) return null;

      final languageLength = payloadBytes[0] & 0x3F; // Lower 6 bits
      if (payloadBytes.length < 1 + languageLength) return null;

      final textStart = 1 + languageLength;
      final textBytes = payloadBytes.sublist(textStart);
      return utf8.decode(textBytes);
    } catch (e) {
      return null;
    }
  }

  /// Returns the language code if this is a WKT Text record
  String? get textLanguage {
    if (type != NdefTypeField.text || payload == null) return null;

    try {
      final payloadBytes = payload!.buffer;
      if (payloadBytes.isEmpty) return null;

      final languageLength = payloadBytes[0] & 0x3F; // Lower 6 bits
      if (payloadBytes.length < 1 + languageLength) return null;

      final languageBytes = payloadBytes.sublist(1, 1 + languageLength);
      return utf8.decode(languageBytes);
    } catch (e) {
      return null;
    }
  }

  /// Returns the URI if this is a WKT URI record
  String? get uriContent {
    if (type != NdefTypeField.uri || payload == null) return null;

    try {
      final payloadBytes = payload!.buffer;
      if (payloadBytes.isEmpty) return null;

      final identifierCode = payloadBytes[0];
      final uriFieldBytes = payloadBytes.sublist(1);
      final uriField = utf8.decode(uriFieldBytes);

      // Reconstruct full URI
      return _reconstructUri(identifierCode, uriField);
    } catch (e) {
      return null;
    }
  }

  /// Returns the JSON data if this is a text/json media type record
  Map<String, dynamic>? get jsonContent {
    if (type != NdefTypeField.textJson || payload == null) return null;

    try {
      final jsonString = utf8.decode(payload!.buffer);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Helper method to reconstruct full URI from identifier code and field
  static String _reconstructUri(int identifierCode, String uriField) {
    final scheme = _codeToUriScheme[identifierCode];
    if (scheme != null) {
      return scheme + uriField;
    }
    return uriField; // No abbreviation (0x00)
  }
}
