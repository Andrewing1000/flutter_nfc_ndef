import 'dart:typed_data';

/// Utility class for creating AIDs
class AidUtils {
  /// Create the standard NDEF AID
  static Uint8List createStandardNdefAid() {
    return Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);
  }

  /// Create a custom AID
  static Uint8List createCustomAid(List<int> aidBytes) {
    if (aidBytes.length < 5 || aidBytes.length > 16) {
      throw ArgumentError('AID must be between 5 and 16 bytes');
    }
    return Uint8List.fromList(aidBytes);
  }

  /// Format AID as hex string for debugging
  static String formatAid(Uint8List aid) {
    return aid
        .map((byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0'))
        .join('');
  }
}

/// NFC state enumeration
enum NfcState {
  enabled('NFC is enabled and available'),
  disabled('NFC is disabled'),
  notSupported('NFC is not supported on this device'),
  unknown('NFC state is unknown');

  const NfcState(this.description);

  final String description;

  static NfcState fromString(String state) {
    switch (state.toLowerCase()) {
      case 'enabled':
        return NfcState.enabled;
      case 'disabled':
        return NfcState.disabled;
      case 'not_supported':
        return NfcState.notSupported;
      default:
        return NfcState.unknown;
    }
  }
}
