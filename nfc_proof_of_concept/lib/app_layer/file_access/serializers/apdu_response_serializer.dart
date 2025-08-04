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

  factory ApduResponse.success({Uint8List? data}) {
    return ApduResponse._internal(
      data: (data != null && data.isNotEmpty)
          ? ApduData(data, name: "Response Data")
          : null,
      statusWord: ApduStatusWord.ok,
      name: "Success Response",
    );
  }

  
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
    // The R-APDU structure is [Data (optional)] + [Status Word].
    // The base ApduSerializer will correctly handle the case where `data` is null.
    fields = [
      data,
      statusWord,
    ];
  }
}