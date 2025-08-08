import 'dart:typed_data';

import '../../field.dart';
import '../fields/response_fields.dart';

class ApduResponse extends ApduSerializer {
  final ApduData? data;
  final ApduStatusWord statusWord;

  ApduResponse._internal({
    this.data,
    required this.statusWord,
    required String name,
  }) : super(name: name);

  factory ApduResponse.fromBytes(Uint8List rawResponse) {
    if (rawResponse.length < 2) {
      throw ArgumentError('Invalid APDU response: must be at least 2 bytes for the status word. Got ${rawResponse.length} bytes.');
    }

    final dataLength = rawResponse.length - 2;
    final responseData = (dataLength > 0)
        ? ApduData(rawResponse.sublist(0, dataLength), name: "Response Data (Parsed)")
        : null;

    final sw1 = rawResponse[dataLength];
    final sw2 = rawResponse[dataLength + 1];
    final statusWord = ApduStatusWord.fromBytes(sw1, sw2);
    
    return ApduResponse._internal(
      data: responseData,
      statusWord: statusWord,
      name: "Parsed Response",
    );
  }

  factory ApduResponse.success({Uint8List? data}) {
    return ApduResponse._internal(
      data: (data != null && data.isNotEmpty)
          ? ApduData(data, name: "Response Data")
          : null,
      statusWord: ApduStatusWord.ok,
      name: "Success Response",
    );
  }

  /// Creates an error response with the specified status word.
  factory ApduResponse.error(ApduStatusWord errorStatus) {
    if (errorStatus == ApduStatusWord.ok) {
      throw ArgumentError('Cannot create an error response with SW=9000. Use success() factory.');
    }
    return ApduResponse._internal(
      statusWord: errorStatus,
      name: "Error Response",
    );
  }

  @override
  void setFields() {
    fields = [
      data,
      statusWord,
    ];
  }
}