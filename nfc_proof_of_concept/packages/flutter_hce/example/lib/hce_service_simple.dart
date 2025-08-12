import 'dart:async';
import 'package:flutter_hce/hce_manager.dart';
import 'package:flutter_hce/hce_types.dart';
import 'package:flutter_hce/hce_utils.dart';
import 'package:flutter_hce/app_layer/utils/utils.dart';
import 'package:flutter_hce/app_layer/file_access/serializers/apdu_command_serializer.dart';
import 'package:flutter_hce/app_layer/file_access/serializers/apdu_response_serializer.dart';

/// Simplified HCE service that only handles JSON data transmission
class HceService {
  static final HceService _instance = HceService._internal();
  factory HceService() => _instance;
  HceService._internal();

  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final StreamController<bool> _hceStatusController =
      StreamController<bool>.broadcast();
  final StreamController<NfcState> _nfcStateController =
      StreamController<NfcState>.broadcast();

  bool _isHceActive = false;
  NfcState _nfcState = NfcState.unknown;

  // Getters for streams
  Stream<String> get logStream => _logController.stream;
  Stream<bool> get hceStatusStream => _hceStatusController.stream;
  Stream<NfcState> get nfcStateStream => _nfcStateController.stream;

  // Getters for current state
  bool get isHceActive => _isHceActive;
  NfcState get nfcState => _nfcState;

  /// Initialize the service and check NFC state
  Future<void> initialize() async {
    await checkNfcState();
  }

  /// Check current NFC state
  Future<void> checkNfcState() async {
    try {
      final state = await FlutterHceManager.instance.checkNfcState();
      _nfcState = state;
      _nfcStateController.add(state);
      _addLog('📱 NFC State: ${state.description}');
    } catch (e) {
      _addLog('🚨 Error checking NFC state: $e');
    }
  }

  /// Start HCE with JSON data - THE MAIN FUNCTIONALITY
  Future<bool> startJsonHce({
    Map<String, dynamic>? jsonData,
  }) async {
    if (_nfcState != NfcState.enabled) {
      _addLog('❌ NFC is not enabled');
      return false;
    }

    final data = jsonData ??
        {
          'app_name': 'Flutter HCE Demo',
          'version': '1.0.0',
          'type': 'NFC JSON Card Emulation',
          'timestamp': DateTime.now().toIso8601String(),
          'message': 'Hello from Flutter HCE!',
          'data': {
            'user_id': 12345,
            'session_token': 'abc123',
            'permissions': ['read', 'write'],
          }
        };

    _addLog('🚀 Starting HCE with JSON card...');
    _addLog('📄 JSON Payload: $data');

    try {
      // Use our new NdefParser for JSON - SIMPLIFIED!
      final jsonRecord = NdefParser.json(data);

      final success = await FlutterHceManager.instance.initialize(
        aid: AidUtils.createStandardNdefAid(),
        records: [jsonRecord.serializer],
        isWritable: false,
        maxNdefFileSize: 4096, // Larger size for JSON
        onTransaction: _handleTransaction,
        onDeactivation: _handleDeactivation,
        onError: _handleError,
      );

      if (success) {
        _addLog('✅ HCE initialized successfully!');
        _addLog('📡 Ready to receive NFC transactions...');
        _addLog(
            '📱 AID: ${AidUtils.formatAid(AidUtils.createStandardNdefAid())}');
        _addLog('🎯 Data Size: ${jsonRecord.toBytes().length} bytes');
        _setHceActive(true);
      } else {
        _addLog('❌ Failed to initialize HCE');
      }

      return success;
    } catch (e) {
      _addLog('🚨 Error starting JSON HCE: $e');
      return false;
    }
  }

  /// Stop HCE
  Future<void> stopHce() async {
    try {
      await FlutterHceManager.instance.stop();
      _addLog('🛑 HCE stopped');
      _setHceActive(false);
    } catch (e) {
      _addLog('🚨 Error stopping HCE: $e');
    }
  }

  /// Handle APDU transactions using our new parsers
  void _handleTransaction(ApduCommand command, ApduResponse response) {
    try {
      // Use our new parsers - wrap the existing objects
      final cmdParser = ApduCommandParser.fromBytes(command.buffer);
      final respParser = ApduResponseParser.fromBytes(response.buffer);

      _addLog('📨 APDU Transaction:');
      _addLog('   Command: ${cmdParser.toString()}');
      _addLog('   Response: ${respParser.toString()}');

      // Log specific details for JSON use case
      if (cmdParser.isSelect) {
        final fileId = cmdParser.selectedFileId;
        if (fileId != null) {
          final fileIdHex = fileId
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join()
              .toUpperCase();
          _addLog('   📁 Selected File ID: 0x$fileIdHex');
        }
      } else if (cmdParser.isReadBinary) {
        _addLog(
            '   📖 Reading ${cmdParser.readLength} bytes from offset ${cmdParser.binaryOffset}');
      }

      if (respParser.isSuccess) {
        final dataLength = respParser.responseData?.length ?? 0;
        if (dataLength > 0) {
          _addLog('   ✅ Success: $dataLength bytes returned');
        } else {
          _addLog('   ✅ Success: No data');
        }
      } else {
        _addLog('   ❌ Error: ${respParser.errorMessage}');
      }
    } catch (e) {
      _addLog('🚨 Error parsing transaction: $e');
    }
  }

  void _handleDeactivation(HceDeactivationReason reason) {
    _addLog('📴 NFC field deactivated: ${reason.description}');
  }

  void _handleError(HceException error) {
    _addLog('🚨 HCE Error: ${error.message}');
  }

  void _setHceActive(bool active) {
    _isHceActive = active;
    _hceStatusController.add(active);
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = '[$timestamp] $message';
    _logController.add(logMessage);
  }

  void dispose() {
    _logController.close();
    _hceStatusController.close();
    _nfcStateController.close();
  }
}
