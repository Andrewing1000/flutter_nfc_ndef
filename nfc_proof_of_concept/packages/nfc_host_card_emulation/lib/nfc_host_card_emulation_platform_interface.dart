import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:nfc_host_card_emulation/app_layer/file_access/serializers/apdu_command_serializer.dart';
import 'package:nfc_host_card_emulation/app_layer/file_access/serializers/apdu_response_serializer.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'nfc_host_card_emulation_method_channel.dart';

class HceTransaction {
  final ApduCommand command;
  final ApduResponse response;
  HceTransaction({required Uint8List command, required Uint8List response})
      : command = ApduCommand.fromBytes(command),
        response = ApduResponse.fromBytes(response);
}

class NdefRecordData {
  final String type;
  final Uint8List payload;
  NdefRecordData({required this.type, required this.payload});

  Map<String, dynamic> toMap() {
    return {'type': type, 'payload': payload};
  }
}

enum NfcState { enabled, disabled, notSupported }

abstract class NfcHostCardEmulationPlatform extends PlatformInterface {
  NfcHostCardEmulationPlatform() : super(token: _token);
  static final Object _token = Object();
  static NfcHostCardEmulationPlatform _instance =
      MethodChannelNfcHostCardEmulation();
  static NfcHostCardEmulationPlatform get instance => _instance;
  static set instance(NfcHostCardEmulationPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Disposes of any resources held by the platform implementation.
  @mustCallSuper
  void dispose() {}

  Future<void> init({required Uint8List aid});
  Stream<HceTransaction> get transactionStream;

  Future<void> addOrUpdateNdefFile({
    required int fileId,
    required List<NdefRecordData> records,
    int maxFileSize = 2048,
    bool isWritable = false,
  });

  Future<void> deleteNdefFile({required int fileId});
  Future<void> clearAllFiles();
  Future<bool> hasFile({required int fileId});
  Future<NfcState> checkDeviceNfcState();
}
