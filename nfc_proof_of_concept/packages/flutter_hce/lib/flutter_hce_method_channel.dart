import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_hce_platform_interface.dart';

/// An implementation of [FlutterHcePlatform] that uses method channels.
class MethodChannelFlutterHce extends FlutterHcePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('nfc_host_card_emulation');

  /// Event channel for HCE transaction events
  @visibleForTesting
  final eventChannel = const EventChannel('nfc_host_card_emulation_events');

  /// Event channel for NFC Intent events (app launching)
  @visibleForTesting
  final intentEventChannel = const EventChannel('nfc_intent_events');

  @override
  Future<bool> init({
    required Uint8List aid,
    required List<NdefRecord> records,
    bool isWritable = false,
    int maxNdefFileSize = 2048,
  }) async {
    try {
      final result = await methodChannel.invokeMethod<bool>('init', {
        'aid': aid,
        'records': records.map((record) => record.toMap()).toList(),
        'isWritable': isWritable,
        'maxNdefFileSize': maxNdefFileSize,
      });
      return result ?? false;
    } catch (e) {
      throw FlutterHceException('Failed to initialize HCE: $e');
    }
  }

  @override
  Future<String> checkNfcState() async {
    try {
      final result = await methodChannel.invokeMethod<String>('checkNfcState');
      return result ?? 'unknown';
    } catch (e) {
      throw FlutterHceException('Failed to check NFC state: $e');
    }
  }

  @override
  Future<bool> isStateMachineInitialized() async {
    try {
      final result =
          await methodChannel.invokeMethod<String>('getStateMachine');
      return result != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getNfcIntent() async {
    try {
      final result = await methodChannel
          .invokeMethod<Map<Object?, Object?>>('getNfcIntent');
      if (result == null) return null;

      return result.map((key, value) => MapEntry(key.toString(), value));
    } catch (e) {
      print('Error getting NFC intent: $e');
      return null;
    }
  }

  @override
  Stream<HceTransactionEvent> get transactionEvents {
    return eventChannel.receiveBroadcastStream().map((event) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(event);
      return HceTransactionEvent.fromMap(data);
    });
  }

  @override
  Stream<Map<String, dynamic>> get nfcIntentEvents {
    return intentEventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event);
    });
  }
}

/// Represents an NDEF record for HCE
class NdefRecord {
  final String type;
  final Uint8List payload;
  final Uint8List? id;

  const NdefRecord({
    required this.type,
    required this.payload,
    this.id,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'payload': payload,
      if (id != null) 'id': id,
    };
  }
}

/// Represents an HCE transaction event
class HceTransactionEvent {
  final Uint8List? command;
  final Uint8List? response;
  final int? reason;
  final HceEventType type;

  const HceTransactionEvent({
    this.command,
    this.response,
    this.reason,
    required this.type,
  });

  factory HceTransactionEvent.fromMap(Map<String, dynamic> map) {
    if (map.containsKey('command') && map.containsKey('response')) {
      return HceTransactionEvent(
        type: HceEventType.transaction,
        command: map['command'] as Uint8List?,
        response: map['response'] as Uint8List?,
      );
    } else if (map.containsKey('reason')) {
      return HceTransactionEvent(
        type: HceEventType.deactivated,
        reason: map['reason'] as int?,
      );
    } else {
      throw ArgumentError('Invalid HCE event data: $map');
    }
  }
}

/// Types of HCE events
enum HceEventType {
  transaction,
  deactivated,
}

/// Exception thrown when HCE operations fail
class FlutterHceException implements Exception {
  final String message;
  const FlutterHceException(this.message);

  @override
  String toString() => 'FlutterHceException: $message';
}
