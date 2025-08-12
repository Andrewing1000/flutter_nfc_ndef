import 'dart:typed_data';

import '../file_access/serializers/apdu_response_serializer.dart';
import '../file_access/fields/response_fields.dart';

/// High-level wrapper for APDU response parsing
/// Simplifies success/error detection and data extraction
class ApduResponseParser {
  final ApduResponse _response;

  ApduResponseParser._(this._response);

  /// Creates a parser from raw response bytes
  factory ApduResponseParser.fromBytes(Uint8List rawResponse) {
    final response = ApduResponse.fromBytes(rawResponse);
    return ApduResponseParser._(response);
  }

  /// Creates a successful response parser
  factory ApduResponseParser.success({Uint8List? data}) {
    final response = ApduResponse.success(data: data);
    return ApduResponseParser._(response);
  }

  /// Creates an error response parser
  factory ApduResponseParser.error(ApduStatusWord errorStatus) {
    final response = ApduResponse.error(errorStatus);
    return ApduResponseParser._(response);
  }

  // Convenient boolean checks

  /// Returns true if the operation was successful (SW = 9000)
  bool get isSuccess => _response.statusWord == ApduStatusWord.ok;

  /// Returns true if there was an error
  bool get isError => !isSuccess;

  /// Returns true if file was not found (SW = 6A82)
  bool get isFileNotFound =>
      _response.statusWord == ApduStatusWord.fileNotFound;

  /// Returns true if wrong parameters were provided (SW = 6A86)
  bool get isWrongParameters =>
      _response.statusWord == ApduStatusWord.wrongP1P2;

  /// Returns true if the operation is not supported (SW = 6D00)
  bool get isUnsupported =>
      _response.statusWord == ApduStatusWord.insNotSupported;

  // Data access

  /// Gets the response data (null if no data or error)
  Uint8List? get responseData {
    return isSuccess ? _response.data?.buffer : null;
  }

  /// Gets the status word as a 2-byte array
  Uint8List get statusWordBytes => _response.statusWord.buffer;

  /// Gets the status word as hex string (e.g., "9000", "6A82")
  String get statusWordHex {
    final sw = statusWordBytes;
    return sw
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  /// Gets a human-readable error message
  String get errorMessage {
    if (isSuccess) return 'Success';
    if (isFileNotFound) return 'File not found';
    if (isWrongParameters) return 'Wrong parameters';
    if (isUnsupported) return 'Operation not supported';
    return 'Error: SW=$statusWordHex';
  }

  /// Gets the underlying response serializer (for advanced use)
  ApduResponse get response => _response;

  /// Serializes back to bytes
  Uint8List toBytes() {
    return _response.buffer;
  }

  /// Developer-friendly string representation
  @override
  String toString() {
    if (isSuccess) {
      final dataLength = responseData?.length ?? 0;
      return 'ApduResponseParser.success(${dataLength} bytes data)';
    } else {
      return 'ApduResponseParser.error($errorMessage)';
    }
  }

  /// JSON representation for debugging
  Map<String, dynamic> toJson() {
    return {
      'success': isSuccess,
      'status_word': statusWordHex,
      'error_message': isError ? errorMessage : null,
      'data_length': responseData?.length ?? 0,
      'has_data': responseData != null,
    };
  }
}
