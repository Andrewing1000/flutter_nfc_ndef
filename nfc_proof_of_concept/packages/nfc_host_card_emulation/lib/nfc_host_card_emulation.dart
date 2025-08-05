import 'dart:async';
import 'dart:typed_data';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation_platform_interface.dart';

class NfcHce {
  static NfcHostCardEmulationPlatform get _platform =>
      NfcHostCardEmulationPlatform.instance;
  static final _apduController = StreamController<NfcApduCommand>.broadcast();

  /// The stream that will notify about the received APDU commands.
  /// Listen to it and do some action.
  static Stream<NfcApduCommand> get stream => _apduController.stream;

  /// Initializes the HCE with the specified parameters:
  /// - `aid`: AID for connection. Must be a Uint8List with a length from 5 to 16
  /// and match at least one aid-filter in apduservice.xml.
  /// - `permanentApduResponses`: determines whether APDU responses from the ports
  /// on which the connection occurred will be deleted. If `true`, responses will be deleted, otherwise won't.
  /// - `listenOnlyConfiguredPorts`: determines whether APDU commands received on ports
  /// to which there are no responses will be added to the stream. If `true`, command won't be added, otherwise will.
  static Future<void> init({
    required Uint8List aid,
    required bool permanentApduResponses,
    required bool listenOnlyConfiguredPorts,
  }) async {
    if (aid.length > 16 || aid.length < 5) {
      throw "AID length exception. Length must be from 5 to 16";
    }

    await _platform.init(
      {
        'permanentApduResponses': permanentApduResponses,
        'listenOnlyConfiguredPorts': listenOnlyConfiguredPorts,
        'aid': aid,
        'cla': null,
        'ins': null,
      },
      _apduController,
    );
  }

  static Future<void> addApduResponse(int port, List<int> data) async {
    await _platform.addApduResponse(port, Uint8List.fromList(data));
  }

  static Future<void> removeApduResponse(int port) async {
    await _platform.removeApduResponse(port);
  }

  static Future<NfcState> checkDeviceNfcState() async {
    return await _platform.checkDeviceNfcState();
  }
}

class NfcApduCommand {
  final int port;

  final Uint8List command;

  final Uint8List? data;

  const NfcApduCommand(this.port, this.command, this.data);
}

enum NfcState {
  enabled,
  disabled,
  notSupported,
}
