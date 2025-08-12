import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

// Import HCE components - CORRECTED IMPORTS
import 'package:flutter_hce/hce_manager.dart';
import 'package:flutter_hce/hce_types.dart';
import 'package:flutter_hce/hce_utils.dart';
import 'package:flutter_hce/app_layer/utils/utils.dart';
import 'package:flutter_hce/app_layer/utils/ndef_parser.dart';
import 'package:flutter_hce/app_layer/ndef_format/serializers/ndef_record_serializer.dart';
import 'package:flutter_hce/app_layer/file_access/serializers/apdu_command_serializer.dart';
import 'package:flutter_hce/app_layer/file_access/serializers/apdu_response_serializer.dart';

import 'ndef_reader_service.dart';

enum NfcBarMode { broadcastOnly, readOnly }

/// Manages NFC state and operations as a ChangeNotifier
/// Supports both HCE (Host Card Emulation) and NFC Manager modes
class NfcService extends ChangeNotifier {
  bool _isReady = false;
  bool _isChecking = false;
  bool _isTransactionActive = false;
  NfcBarMode? _currentMode;
  String? _lastError;

  bool _nfcSessionActive = false;
  FlutterHceManager? _hceManager;
  final NdefReaderService _ndefReader = NdefReaderService();

  bool get isReady => _isReady;
  bool get isChecking => _isChecking;
  bool get isTransactionActive => _isTransactionActive;
  NfcBarMode? get currentMode => _currentMode;
  String? get lastError => _lastError;

  Future<bool> checkNfcState({
    String? broadcastData,
    NfcBarMode? mode,
    List<int>? aid,
  }) async {
    if (_isChecking) return _isReady;

    _setChecking(true);
    _clearError();

    try {
      // Check basic NFC availability
      final isNfcAvailable = await NfcManager.instance.isAvailable();
      if (!isNfcAvailable) {
        _setError('NFC no está disponible en este dispositivo');
        _setReady(false);
        return false;
      }

      // Initialize based on mode
      if (mode == NfcBarMode.broadcastOnly && aid != null) {
        return await _initializeHceMode(broadcastData, aid);
      } else if (mode == NfcBarMode.readOnly) {
        return await _initializeReadMode();
      } else {
        _setError('Modo o AID no especificados correctamente');
        _setReady(false);
        return false;
      }
    } catch (e) {
      _setError('Error al inicializar NFC: $e');
      _setReady(false);
      return false;
    } finally {
      _setChecking(false);
    }
  }

  Future<bool> _initializeHceMode(String? broadcastData, List<int> aid) async {
    try {
      await _stopAll();

      _hceManager = FlutterHceManager.instance;

      final nfcState = await _hceManager!.checkNfcState();
      debugPrint('NFC State: ${nfcState.description}');

      if (nfcState != NfcState.enabled) {
        _setError('NFC no está habilitado en este dispositivo');
        return false;
      }

      List<NdefRecordSerializer> records = [];

      if (broadcastData != null && broadcastData.isNotEmpty) {
        try {
          final jsonData = json.decode(broadcastData) as Map<String, dynamic>;
          final ndefParser = NdefParser.json(jsonData);
          records.add(ndefParser.serializer);
          debugPrint('Created JSON NDEF record: ${jsonData.toString()}');
        } catch (e) {
          final ndefParser = NdefParser.text(broadcastData);
          records.add(ndefParser.serializer);
          debugPrint('Created text NDEF record: $broadcastData');
        }
      }

      if (records.isEmpty) {
        final defaultData = {
          'app': 'Flutter NFC Demo',
          'timestamp': DateTime.now().toIso8601String(),
          'message': 'Hello from Flutter HCE!'
        };
        final ndefParser = NdefParser.json(defaultData);
        records.add(ndefParser.serializer);
      }

      final success = await _hceManager!.initialize(
        aid: Uint8List.fromList(aid),
        records: records,
        isWritable: false,
        maxNdefFileSize: 4096,
        onTransaction: _onHceTransaction,
        onDeactivation: _onHceDeactivation,
        onError: _onHceError,
      );

      if (success) {
        _currentMode = NfcBarMode.broadcastOnly;
        _setReady(true);
        debugPrint(
            'HCE initialized successfully with AID: ${AidUtils.formatAid(Uint8List.fromList(aid))}');
        return true;
      } else {
        _setError('No se pudo inicializar HCE');
        return false;
      }
    } catch (e) {
      _setError('Error en modo HCE: $e');
      debugPrint('HCE Error: $e');
      return false;
    }
  }

  Future<bool> _initializeReadMode() async {
    try {
      await _stopAll();

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          _setTransactionActive(true);

          try {
            final ndefData = await _ndefReader.readNdefFromTag(tag);
            if (ndefData != null) {
              debugPrint('NDEF Data read successfully: $ndefData');
            } else {
              debugPrint('No NDEF data found or read failed');
            }
          } catch (e) {
            debugPrint('Error reading NDEF data: $e');
            _setError('Error leyendo datos NDEF: $e');
          } finally {
            Timer(const Duration(milliseconds: 1500), () {
              _setTransactionActive(false);
            });
          }
        },
      );

      _nfcSessionActive = true;
      _currentMode = NfcBarMode.readOnly;
      _setReady(true);
      return true;
    } catch (e) {
      _setError('Error en modo lectura: $e');
      return false;
    }
  }

  Future<void> _stopAll() async {
    if (_nfcSessionActive) {
      NfcManager.instance.stopSession();
      _nfcSessionActive = false;
    }

    // Stop HCE session if active
    if (_hceManager != null) {
      try {
        await _hceManager!.stop();
        debugPrint('HCE session stopped');
      } catch (e) {
        debugPrint('Warning stopping HCE: $e');
      }
      _hceManager = null;
    }
  }

  void _setReady(bool ready) {
    if (_isReady != ready) {
      _isReady = ready;
      notifyListeners();
    }
  }

  void _setChecking(bool checking) {
    if (_isChecking != checking) {
      _isChecking = checking;
      notifyListeners();
    }
  }

  void _setTransactionActive(bool active) {
    if (_isTransactionActive != active) {
      _isTransactionActive = active;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_lastError != error) {
      _lastError = error;
      notifyListeners();
    }
  }

  void _clearError() {
    _setError(null);
  }

  void reset() {
    _stopAll();
    _isReady = false;
    _isChecking = false;
    _isTransactionActive = false;
    _currentMode = null;
    _lastError = null;
    notifyListeners();
  }

  void _onHceTransaction(ApduCommand command, ApduResponse response) {
    debugPrint(
        'HCE Transaction: ${command.toString()} -> ${response.toString()}');
    _setTransactionActive(true);

    Future.delayed(const Duration(seconds: 2), () {
      _setTransactionActive(false);
    });
  }

  void _onHceDeactivation(HceDeactivationReason reason) {
    debugPrint('HCE Deactivated: ${reason.description}');
    _setTransactionActive(false);
  }

  void _onHceError(HceException error) {
    debugPrint('HCE Error: ${error.toString()}');
    _setError('Error HCE: ${error.message}');
    _setTransactionActive(false);
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
