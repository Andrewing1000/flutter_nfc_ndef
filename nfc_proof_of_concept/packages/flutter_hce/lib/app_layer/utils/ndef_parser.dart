import 'dart:typed_data';

import '../ndef_format/serializers/ndef_record_serializer.dart';
import '../ndef_format/fields/ndef_record_fields.dart';

/// High-level wrapper for NDEF record creation and parsing
/// Simplifies JSON handling and provides developer-friendly APIs
class NdefParser {
  final NdefRecordSerializer _serializer;

  NdefParser._(this._serializer);

  /// Creates an NDEF Text record with automatic payload formatting
  factory NdefParser.text(String text, {String language = 'en'}) {
    final serializer = NdefRecordSerializer.text(text, language);
    return NdefParser._(serializer);
  }

  /// Creates an NDEF URI record with automatic scheme handling
  factory NdefParser.uri(String uri) {
    final serializer = NdefRecordSerializer.uri(uri);
    return NdefParser._(serializer);
  }

  /// Creates an NDEF JSON record - THE MAIN USE CASE
  /// Takes a Map and automatically converts to JSON payload
  factory NdefParser.json(Map<String, dynamic> data) {
    final serializer = NdefRecordSerializer.json(data);
    return NdefParser._(serializer);
  }

  /// Parses raw NDEF bytes and creates a user-friendly wrapper
  factory NdefParser.fromBytes(Uint8List rawRecord) {
    final serializer = NdefRecordSerializer.fromBytes(rawRecord);
    return NdefParser._(serializer);
  }

  // Convenient getters for developers

  /// Returns the record type (text, uri, json, etc.)
  String get recordType {
    if (_serializer.type == NdefTypeField.text) return 'text';
    if (_serializer.type == NdefTypeField.uri) return 'uri';
    if (_serializer.type == NdefTypeField.textJson) return 'json';
    if (_serializer.type == NdefTypeField.smartPoster) return 'smart_poster';
    return 'unknown';
  }

  /// Returns true if this is a JSON record
  bool get isJson => recordType == 'json';

  /// Returns true if this is a text record
  bool get isText => recordType == 'text';

  /// Returns true if this is a URI record
  bool get isUri => recordType == 'uri';

  /// Gets the JSON data directly (for JSON records)
  /// Returns null if not a JSON record
  Map<String, dynamic>? get jsonData {
    return _serializer.jsonContent;
  }

  /// Gets the text content directly (for text records)
  /// Returns null if not a text record
  String? get textContent {
    return _serializer.textContent;
  }

  /// Gets the text language (for text records)
  /// Returns null if not a text record
  String? get textLanguage {
    return _serializer.textLanguage;
  }

  /// Gets the URI content directly (for URI records)
  /// Returns null if not a URI record
  String? get uriContent {
    return _serializer.uriContent;
  }

  /// Gets the raw payload bytes (for advanced use)
  Uint8List? get rawPayload {
    return _serializer.payload?.buffer;
  }

  /// Serializes to bytes for transmission
  Uint8List toBytes() {
    return _serializer.buffer;
  }

  /// Gets the underlying serializer (for advanced use)
  NdefRecordSerializer get serializer => _serializer;

  /// Developer-friendly string representation
  @override
  String toString() {
    switch (recordType) {
      case 'json':
        return 'NdefParser.json(${jsonData.toString()})';
      case 'text':
        return 'NdefParser.text("$textContent", language: "$textLanguage")';
      case 'uri':
        return 'NdefParser.uri("$uriContent")';
      default:
        return 'NdefParser.${recordType}()';
    }
  }

  /// Convenient JSON conversion (mainly for JSON records)
  Map<String, dynamic> toJson() {
    return {
      'type': recordType,
      'data': _getRecordData(),
    };
  }

  Map<String, dynamic> _getRecordData() {
    switch (recordType) {
      case 'json':
        return jsonData ?? {};
      case 'text':
        return {
          'content': textContent,
          'language': textLanguage,
        };
      case 'uri':
        return {'uri': uriContent};
      default:
        return {'raw_payload': rawPayload?.toList()};
    }
  }
}
