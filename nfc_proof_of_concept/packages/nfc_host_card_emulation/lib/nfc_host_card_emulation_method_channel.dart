import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nfc_host_card_emulation/app_layer/ndef_format/serializers/ndef_record_serializer.dart';
import 'package:nfc_host_card_emulation/app_layer/errors.dart';

import 'nfc_host_card_emulation_platform_interface.dart';

class MethodChannelNfcHostCardEmulation extends NfcHostCardEmulationPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('nfc_host_card_emulation');

  final StreamController<HceTransaction> _transactionStreamController =
      StreamController.broadcast();
  bool _isDisposed = false;

  MethodChannelNfcHostCardEmulation() {
    methodChannel.setMethodCallHandler(_handleNativeMethodCall);
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _transactionStreamController.close();
      _isDisposed = true;
    }
    super.dispose();
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onHceTransaction':
        final args = call.arguments as Map;
        final command = args['command'] as Uint8List;
        final response = args['response'] as Uint8List;
        _transactionStreamController
            .add(HceTransaction(command: command, response: response));
        break;
      case 'onHceDeactivated':
        if (kDebugMode) print('HCE Deactivated, reason: ${call.arguments}');
        break;
    }
  }

  @override
  Stream<HceTransaction> get transactionStream =>
      _transactionStreamController.stream;

  @override
  Future<void> init({required Uint8List aid}) async {
    try {
      await methodChannel.invokeMethod('init', {'aid': aid});
    } on PlatformException catch (e) {
      final code = e.code == 'NOT_SUPPORTED'
          ? HceErrorCode.serviceNotAvailable
          : HceErrorCode.unknown;
      throw HceException(code, "Failed to initialize HCE", details: e.message);
    }
  }

  @override
  Future<void> addOrUpdateNdefFile({
    required int fileId,
    required List<NdefRecordData> records,
    int maxFileSize = 2048,
    bool isWritable = false,
  }) async {
    try {
      final recordsAsMaps = records.map((r) => r.toMap()).toList();

      await methodChannel.invokeMethod('addOrUpdateFile', {
        'fileId': fileId,
        'records': recordsAsMaps,
        'maxFileSize': maxFileSize,
        'isWritable': isWritable,
      });
    } on PlatformException catch (e) {
      final code = _mapErrorCode(e.code);
      throw HceException(code, "Failed to add/update file", details: e.message);
    }
  }

  HceErrorCode _mapErrorCode(String platformCode) {
    switch (platformCode) {
      case 'NOT_SUPPORTED':
        return HceErrorCode.serviceNotAvailable;
      case 'NOT_INITIALIZED':
        return HceErrorCode.invalidState;
      case 'FILE_EXISTS':
        return HceErrorCode.fileNotFound;
      case 'INVALID_FILE_ID':
        return HceErrorCode.invalidFileId;
      case 'FILE_TOO_LARGE':
        return HceErrorCode.messageTooLarge;
      case 'INVALID_NDEF':
        return HceErrorCode.invalidNdefFormat;
      case 'INVALID_AID':
        return HceErrorCode.invalidAid;
      case 'FILE_NOT_FOUND':
        return HceErrorCode.fileNotFound;
      case 'INIT_FAILED':
        return HceErrorCode.serviceNotAvailable;
      default:
        return HceErrorCode.unknown;
    }
  }

  @override
  Future<void> deleteNdefFile({required int fileId}) async {
    try {
      await methodChannel.invokeMethod('deleteFile', {'fileId': fileId});
    } on PlatformException catch (e) {
      throw Exception("Failed to delete file: ${e.message}");
    }
  }

  @override
  Future<void> clearAllFiles() async {
    try {
      await methodChannel.invokeMethod('clearAllFiles');
    } on PlatformException catch (e) {
      throw Exception("Failed to clear files: ${e.message}");
    }
  }

  @override
  Future<bool> hasFile({required int fileId}) async {
    try {
      final result =
          await methodChannel.invokeMethod<bool>('hasFile', {'fileId': fileId});
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception("Failed to check for file: ${e.message}");
    }
  }

  @override
  Future<NfcState> checkDeviceNfcState() async {
    try {
      final state = await methodChannel.invokeMethod<String>('checkNfcState');
      switch (state) {
        case 'enabled':
          return NfcState.enabled;
        case 'disabled':
          return NfcState.disabled;
        default:
          return NfcState.notSupported;
      }
    } on PlatformException {
      return NfcState.notSupported;
    }
  }
}
