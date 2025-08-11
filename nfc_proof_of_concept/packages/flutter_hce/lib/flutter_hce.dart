import 'dart:typed_data';

import 'flutter_hce_platform_interface.dart';
import 'flutter_hce_method_channel.dart';

// Export public API classes
export 'flutter_hce_method_channel.dart'
    show NdefRecord, HceTransactionEvent, HceEventType, FlutterHceException;
export 'aid_utils.dart' show AidUtils;

/// Main Flutter HCE class for Host Card Emulation functionality
class FlutterHce {
  static FlutterHcePlatform get _platform => FlutterHcePlatform.instance;

  /// Initialize HCE with NDEF records and AID
  ///
  /// [aid] - Application ID to register for HCE (5-16 bytes)
  /// [records] - List of NDEF records to emulate
  /// [isWritable] - Whether the emulated card should be writable
  /// [maxNdefFileSize] - Maximum size of the NDEF file in bytes
  static Future<bool> init({
    required Uint8List aid,
    required List<NdefRecord> records,
    bool isWritable = false,
    int maxNdefFileSize = 2048,
  }) async {
    return await _platform.init(
      aid: aid,
      records: records,
      isWritable: isWritable,
      maxNdefFileSize: maxNdefFileSize,
    );
  }

  /// Check the current NFC state
  ///
  /// Returns one of: 'enabled', 'disabled', 'not_supported'
  static Future<String> checkNfcState() async {
    return await _platform.checkNfcState();
  }

  /// Check if the HCE state machine is initialized
  static Future<bool> isStateMachineInitialized() async {
    return await _platform.isStateMachineInitialized();
  }

  /// Stream of HCE transaction events
  ///
  /// Listen to this stream to receive APDU commands and responses
  static Stream<HceTransactionEvent> get transactionEvents {
    return _platform.transactionEvents;
  }

  /// Stream of NFC Intent events for app launching
  ///
  /// Listen to this stream to receive events when the app is launched via NFC
  static Stream<Map<String, dynamic>> get nfcIntentEvents {
    return _platform.nfcIntentEvents;
  }

  /// Get NFC intent data if the app was launched via NFC
  ///
  /// Returns null if the app was not launched via NFC
  /// Call this in initState() to check if the app was opened by NFC
  static Future<Map<String, dynamic>?> getNfcIntent() async {
    return await _platform.getNfcIntent();
  }

  /// Check if the app was launched via NFC
  ///
  /// Convenience method that returns true if getNfcIntent() returns non-null data
  static Future<bool> wasLaunchedViaHce() async {
    final intent = await getNfcIntent();
    return intent != null;
  }

  /// Helper method to create a text NDEF record
  static NdefRecord createTextRecord(String text, {String language = 'en'}) {
    // Text Record payload format: [flags][language_code][text]
    final languageBytes = Uint8List.fromList(language.codeUnits);
    final textBytes = Uint8List.fromList(text.codeUnits);
    final flags = languageBytes.length; // No encoding flag (UTF-8)

    final payload = Uint8List(1 + languageBytes.length + textBytes.length);
    payload[0] = flags;
    payload.setRange(1, 1 + languageBytes.length, languageBytes);
    payload.setRange(1 + languageBytes.length, payload.length, textBytes);

    return NdefRecord(
      type: 'T', // Text record type
      payload: payload,
    );
  }

  /// Helper method to create a URI NDEF record
  static NdefRecord createUriRecord(String uri) {
    // URI Record payload format: [identifier_code][uri]
    // identifier_code 0x00 means no abbreviation
    final uriBytes = Uint8List.fromList(uri.codeUnits);
    final payload = Uint8List(1 + uriBytes.length);
    payload[0] = 0x00; // No abbreviation
    payload.setRange(1, payload.length, uriBytes);

    return NdefRecord(
      type: 'U', // URI record type
      payload: payload,
    );
  }

  /// Helper method to create a raw NDEF record
  static NdefRecord createRawRecord({
    required String type,
    required Uint8List payload,
    Uint8List? id,
  }) {
    return NdefRecord(
      type: type,
      payload: payload,
      id: id,
    );
  }

  /// Helper method to create a standard NDEF AID
  ///
  /// Returns the standard NDEF AID: D2760000850101
  /// This is the most commonly used AID for NDEF applications
  static Uint8List createStandardNdefAid() {
    return Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);
  }

  /// Helper method to create a custom AID
  ///
  /// [aidBytes] - List of bytes for the AID (must be 5-16 bytes)
  static Uint8List createCustomAid(List<int> aidBytes) {
    if (aidBytes.length < 5 || aidBytes.length > 16) {
      throw ArgumentError('AID must be between 5 and 16 bytes');
    }
    return Uint8List.fromList(aidBytes);
  }
}

/// NFC state enumeration
enum NfcState {
  enabled,
  disabled,
  notSupported,
  unknown;

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
