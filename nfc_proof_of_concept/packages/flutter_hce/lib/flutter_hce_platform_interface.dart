import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_hce_method_channel.dart';

abstract class FlutterHcePlatform extends PlatformInterface {
  /// Constructs a FlutterHcePlatform.
  FlutterHcePlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterHcePlatform _instance = MethodChannelFlutterHce();

  /// The default instance of [FlutterHcePlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterHce].
  static FlutterHcePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterHcePlatform] when
  /// they register themselves.
  static set instance(FlutterHcePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialize HCE with NDEF records
  Future<bool> init({
    required List<NdefRecord> records,
    bool isWritable = false,
    int maxNdefFileSize = 2048,
  }) {
    throw UnimplementedError('init() has not been implemented.');
  }

  /// Check the current NFC state
  Future<String> checkNfcState() {
    throw UnimplementedError('checkNfcState() has not been implemented.');
  }

  /// Check if the HCE state machine is initialized
  Future<bool> isStateMachineInitialized() {
    throw UnimplementedError(
        'isStateMachineInitialized() has not been implemented.');
  }

  /// Stream of HCE transaction events
  Stream<HceTransactionEvent> get transactionEvents {
    throw UnimplementedError('transactionEvents has not been implemented.');
  }
}
