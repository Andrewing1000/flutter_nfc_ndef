// lib/services/app_launch_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLaunchService {
  static const MethodChannel _channel = MethodChannel('app_launch_info');

  static AppLaunchService? _instance;
  static AppLaunchService get instance => _instance ??= AppLaunchService._();

  AppLaunchService._();

  bool _launchedFromTechDiscovered = false;
  bool get launchedFromTechDiscovered => _launchedFromTechDiscovered;

  Future<void> initialize() async {
    try {
      // Get launch information from native side
      final Map<dynamic, dynamic>? launchInfo =
          await _channel.invokeMethod('getLaunchInfo');

      if (launchInfo != null) {
        _launchedFromTechDiscovered =
            launchInfo['launchedFromTechDiscovered'] ?? false;
        debugPrint(
            'App launched from TECH_DISCOVERED: $_launchedFromTechDiscovered');
      }

      // Set up listener for new intents (when app is already running)
      _channel.setMethodCallHandler(_handleMethodCall);
    } catch (e) {
      debugPrint('Error initializing AppLaunchService: $e');
      _launchedFromTechDiscovered = false;
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'techDiscovered':
        debugPrint('Received TECH_DISCOVERED while app was running');
        _launchedFromTechDiscovered = true;
        // Notify listeners if needed
        _notifyTechDiscovered();
        break;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }

  // Callback for when TECH_DISCOVERED is received while app is running
  VoidCallback? _onTechDiscovered;

  void setTechDiscoveredCallback(VoidCallback callback) {
    _onTechDiscovered = callback;
  }

  void _notifyTechDiscovered() {
    _onTechDiscovered?.call();
  }

  void reset() {
    _launchedFromTechDiscovered = false;
  }
}
