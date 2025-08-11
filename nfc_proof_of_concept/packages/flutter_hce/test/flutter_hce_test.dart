import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hce/flutter_hce.dart';
import 'package:flutter_hce/flutter_hce_platform_interface.dart';
import 'package:flutter_hce/flutter_hce_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterHcePlatform
    with MockPlatformInterfaceMixin
    implements FlutterHcePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterHcePlatform initialPlatform = FlutterHcePlatform.instance;

  test('$MethodChannelFlutterHce is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterHce>());
  });

  test('getPlatformVersion', () async {
    FlutterHce flutterHcePlugin = FlutterHce();
    MockFlutterHcePlatform fakePlatform = MockFlutterHcePlatform();
    FlutterHcePlatform.instance = fakePlatform;

    expect(await flutterHcePlugin.getPlatformVersion(), '42');
  });
}
