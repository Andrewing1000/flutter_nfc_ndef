import 'package:flutter/services.dart';

class FlutterHce {
  static const MethodChannel _channel = MethodChannel('com.viridian/flutter_hce');

  /// Llama al método nativo `addNumbers` implementado en Kotlin.
  static Future<int> addNative(int a, int b) async {
    final result = await _channel.invokeMethod<int>(
      'addNumbers',
      {
        'a': a,
        'b': b,
      },
    );
    return result ?? 0;
  }
}
