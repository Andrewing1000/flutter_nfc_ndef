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

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
