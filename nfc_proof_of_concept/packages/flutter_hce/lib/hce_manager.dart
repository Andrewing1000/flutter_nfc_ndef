import 'dart:async';
import 'package:flutter/services.dart';

import 'hce_types.dart';
import 'hce_utils.dart';
import 'app_layer/file_access/serializers/apdu_command_serializer.dart';
import 'app_layer/file_access/serializers/apdu_response_serializer.dart';
import 'app_layer/ndef_format/serializers/ndef_record_serializer.dart';


class FlutterHceManager {
  static FlutterHceManager? _instance;
  static FlutterHceManager get instance => _instance ??= FlutterHceManager._();

  FlutterHceManager._();

  static const MethodChannel _methodChannel =
      MethodChannel('nfc_host_card_emulation');
  static const EventChannel _eventChannel =
      EventChannel('nfc_host_card_emulation_events');

  StreamSubscription? _eventSubscription;
  HceTransactionCallback? _onTransaction;
  HceDeactivationCallback? _onDeactivation;
  HceErrorCallback? _onError;
  bool _isActive = false;

  Future<bool> initialize({
    required Uint8List aid,
    required List<NdefRecordSerializer> records,
    bool isWritable = false,
    int maxNdefFileSize = 2048,
    HceTransactionCallback? onTransaction,
    HceDeactivationCallback? onDeactivation,
    HceErrorCallback? onError,
  }) async {
    try {
      await stop();

      // Convert NdefRecordSerializer to the format expected by Kotlin
      final recordsData =
          records.map((record) => _convertRecordToMap(record)).toList();

      // Initialize HCE via platform channel
      final result = await _methodChannel.invokeMethod<bool>('init', {
        'aid': aid,
        'records': recordsData,
        'isWritable': isWritable,
        'maxNdefFileSize': maxNdefFileSize,
      });

      if (result == true) {
        _onTransaction = onTransaction;
        _onDeactivation = onDeactivation;
        _onError = onError;
        _startListening();
        _isActive = true;
        return true;
      }
      return false;
    } catch (e) {
      final error = HceException('Failed to initialize HCE: $e');
      onError?.call(error);
      return false;
    }
  }

  Map<String, dynamic> _convertRecordToMap(NdefRecordSerializer record) {
    String typeString = 'T'; // Default
    if (record.type.buffer.isNotEmpty) {
      if (record.type.buffer.length == 1) {
        final typeByte = record.type.buffer[0];
        if (typeByte == 0x54){
          typeString = 'T'; 
        }
        else if (typeByte == 0x55){
          typeString = 'U';
        } 
      } else {
        try {
          typeString = String.fromCharCodes(record.type.buffer);
        } catch (e) {
          typeString = 'T'; // Fallback
        }
      }
    }

    return {
      'type': typeString,
      'payload': record.payload?.buffer ?? Uint8List(0),
      if (record.id != null) 'id': record.id!.buffer,
    };
  }

  /// Start listening to HCE events
  void _startListening() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        try {
          _handleEvent(Map<String, dynamic>.from(event));
        } catch (e) {
          final error = HceException('Event processing error: $e');
          _onError?.call(error);
        }
      },
      onError: (error) {
        final hceError = HceException('Stream error: $error');
        _onError?.call(hceError);
      },
    );
  }

  /// Handle incoming HCE events with intelligent parsing
  void _handleEvent(Map<String, dynamic> eventData) {
    try {
      if (eventData.containsKey('type')) {
        final type = eventData['type'] as String;

        switch (type) {
          case 'transaction':
            _handleTransaction(eventData);
            break;
          case 'deactivated':
            _handleDeactivation(eventData);
            break;
          default:
            final error = HceException('Unknown event type: $type');
            _onError?.call(error);
        }
      }
    } catch (e) {
      final error = HceException('Failed to handle event: $e');
      _onError?.call(error);
    }
  }

  /// Handle transaction events with APDU parsing
  void _handleTransaction(Map<String, dynamic> eventData) {
    if (_onTransaction == null) return;

    try {
      final commandData = eventData['command'] as List<dynamic>?;
      final responseData = eventData['response'] as List<dynamic>?;

      if (commandData != null && responseData != null) {
        final commandBytes = Uint8List.fromList(commandData.cast<int>());
        final responseBytes = Uint8List.fromList(responseData.cast<int>());

        // Parse APDU command and response using app_layer deserializers
        final command = ApduCommand.fromBytes(commandBytes);
        final response = ApduResponse.fromBytes(responseBytes);

        // Call the user's callback with parsed data
        _onTransaction!(command, response);
      }
    } catch (e) {
      final error = HceException('Failed to parse transaction: $e');
      _onError?.call(error);
    }
  }

  /// Handle deactivation events
  void _handleDeactivation(Map<String, dynamic> eventData) {
    if (_onDeactivation == null) return;

    try {
      final reasonCode = eventData['reason'] as int? ?? 2; // Default to RF
      final reason = HceDeactivationReason.fromCode(reasonCode);

      _onDeactivation!(reason);
      _isActive = false;
    } catch (e) {
      final error = HceException('Failed to parse deactivation: $e');
      _onError?.call(error);
    }
  }

  /// Check NFC state
  Future<NfcState> checkNfcState() async {
    try {
      final result = await _methodChannel.invokeMethod<String>('checkNfcState');
      return NfcState.fromString(result ?? 'unknown');
    } catch (e) {
      return NfcState.unknown;
    }
  }

  /// Check if HCE state machine is initialized
  Future<bool> isInitialized() async {
    try {
      final result =
          await _methodChannel.invokeMethod<String>('getStateMachine');
      return result != null;
    } catch (e) {
      return false;
    }
  }

  /// Stop HCE and cleanup resources
  Future<void> stop() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _onTransaction = null;
    _onDeactivation = null;
    _onError = null;
    _isActive = false;
  }

  /// Check if HCE is currently active
  bool get isActive => _isActive;
}
