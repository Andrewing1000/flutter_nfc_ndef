import 'dart:typed_data';
import 'package:flutter/services.dart';

class NfcAidHelper {
  static const MethodChannel _channel = MethodChannel('nfc_aid_helper');

  static Future<Uint8List> getAidFromXml() async {
    try {
      final String? aidString = await _channel.invokeMethod('getAidFromXml');
      if (aidString != null && aidString.isNotEmpty) {
        return _hexStringToUint8List(aidString);
      }
    } catch (e) {
      print('Error retrieving AID from XML: $e');
    }

    return _hexStringToUint8List('A000DADADADADA');
  }

  /// Converts hex string to Uint8List
  static Uint8List _hexStringToUint8List(String hexString) {
    // Remove any whitespace or separators
    final cleanHex = hexString.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');

    // Ensure even length
    final paddedHex = cleanHex.length % 2 == 0 ? cleanHex : '0$cleanHex';

    final bytes = <int>[];
    for (int i = 0; i < paddedHex.length; i += 2) {
      final hexByte = paddedHex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }

    return Uint8List.fromList(bytes);
  }
}
