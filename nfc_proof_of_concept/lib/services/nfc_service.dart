import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

// Import HCE components
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

    _setCheckingQuietly(true);
    _clearErrorQuietly();

    try {
      // Check basic NFC availability
      final isNfcAvailable = await NfcManager.instance.isAvailable();
      if (!isNfcAvailable) {
        _setErrorQuietly('NFC no está disponible en este dispositivo');
        _setReadyQuietly(false);
        notifyListeners(); // Notificar error
        return false;
      }

      // Initialize based on mode
      if (mode == NfcBarMode.broadcastOnly && aid != null) {
        return await _initializeHceMode(broadcastData, aid);
      } else if (mode == NfcBarMode.readOnly) {
        return await _initializeReadMode();
      } else {
        _setErrorQuietly('Modo o AID no especificados correctamente');
        _setReadyQuietly(false);
        notifyListeners(); // Notificar error
        return false;
      }
    } catch (e) {
      _setErrorQuietly('Error al inicializar NFC: $e');
      _setReadyQuietly(false);
      notifyListeners(); // Notificar error
      return false;
    } finally {
      _setCheckingQuietly(false);
    }
  }

  Future<bool> _initializeHceMode(String? broadcastData, List<int> aid) async {
    try {
      await _stopAll();

      _hceManager = FlutterHceManager.instance;

      final nfcState = await _hceManager!.checkNfcState();
      debugPrint('NFC State: ${nfcState.description}');

      if (nfcState != NfcState.enabled) {
        _setErrorQuietly('NFC no está habilitado en este dispositivo');
        return false;
      }

      // BROADCAST MODE: Solo notificar cuando HCE NFC state esté disponible
      _setCurrentModeQuietly(NfcBarMode.broadcastOnly);
      _setReadyQuietly(true);
      notifyListeners(); // Notificar porque HCE NFC state está disponible

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
        debugPrint(
            'HCE initialized successfully with AID: ${AidUtils.formatAid(Uint8List.fromList(aid))}');
        return true;
      } else {
        _setErrorQuietly('No se pudo inicializar HCE');
        _setReadyQuietly(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setErrorQuietly('Error en modo HCE: $e');
      _setReadyQuietly(false);
      notifyListeners();
      debugPrint('HCE Error: $e');
      return false;
    }
  }

  Future<bool> _initializeReadMode() async {
    try {
      await _stopAll();

      // READ ONLY MODE: Notificar cuando NFC esté disponible
      _setCurrentModeQuietly(NfcBarMode.readOnly);
      _setReadyQuietly(true);
      notifyListeners(); // Notificar porque NFC está disponible

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          _setTransactionActiveQuietly(true);
          notifyListeners(); // Notificar actividad de transacción

          try {
            final ndefData = await _ndefReader.readNdefFromTag(tag);
            if (ndefData != null) {
              debugPrint('NDEF Data read successfully: $ndefData');
              // READ ONLY MODE: Notificar cuando se ha leído exitosamente NDEF file
              notifyListeners(); // Notificar lectura exitosa
            } else {
              debugPrint('No NDEF data found or read failed');
            }
          } catch (e) {
            debugPrint('Error reading NDEF data: $e');
            _setErrorQuietly('Error leyendo datos NDEF: $e');
            // No notificar aquí, solo en casos exitosos
          } finally {
            Timer(const Duration(milliseconds: 1500), () {
              _setTransactionActiveQuietly(false);
              notifyListeners(); // Notificar fin de transacción
            });
          }
        },
      );

      _nfcSessionActive = true;
      return true;
    } catch (e) {
      _setErrorQuietly('Error en modo lectura: $e');
      _setReadyQuietly(false);
      notifyListeners();
      return false;
    }
  }

  Future<void> _stopAll() async {
    bool stateChanged = false;

    if (_nfcSessionActive) {
      NfcManager.instance.stopSession();
      _nfcSessionActive = false;
      stateChanged = true;
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
      stateChanged = true;
    }

    if (stateChanged) {
      _setCurrentModeQuietly(null);
      _setReadyQuietly(false);
      // No notificar aquí, esto es solo limpieza interna
    }
  }

  void _setReady(bool ready) {
    if (_isReady != ready) {
      _isReady = ready;
      notifyListeners();
    }
  }

  void _setReadyQuietly(bool ready) {
    _isReady = ready;
  }

  void _setChecking(bool checking) {
    if (_isChecking != checking) {
      _isChecking = checking;
      notifyListeners();
    }
  }

  void _setCheckingQuietly(bool checking) {
    _isChecking = checking;
  }

  void _setTransactionActive(bool active) {
    if (_isTransactionActive != active) {
      _isTransactionActive = active;
      notifyListeners();
    }
  }

  void _setTransactionActiveQuietly(bool active) {
    _isTransactionActive = active;
  }

  void _setCurrentMode(NfcBarMode? mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      notifyListeners();
    }
  }

  void _setCurrentModeQuietly(NfcBarMode? mode) {
    _currentMode = mode;
  }

  void _setError(String? error) {
    if (_lastError != error) {
      _lastError = error;
      notifyListeners();
    }
  }

  void _setErrorQuietly(String? error) {
    _lastError = error;
  }

  void _clearError() {
    _setError(null);
  }

  void _clearErrorQuietly() {
    _setErrorQuietly(null);
  }

  void reset() {
    _stopAll();
    _setReadyQuietly(false);
    _setCheckingQuietly(false);
    _setTransactionActiveQuietly(false);
    _setCurrentModeQuietly(null);
    _clearErrorQuietly();
    notifyListeners(); // Solo notificar el reset completo
  }

  void _onHceTransaction(ApduCommand command, ApduResponse response) {
    debugPrint(
        'HCE Transaction: ${command.toString()} -> ${response.toString()}');

    // BROADCAST MODE: Notificar cuando un lector ha leído exitosamente el NDEF file
    _setTransactionActiveQuietly(true);
    notifyListeners(); // Notificar lectura exitosa por parte del lector

    Future.delayed(const Duration(seconds: 2), () {
      _setTransactionActiveQuietly(false);
      notifyListeners(); // Notificar fin de transacción
    });
  }

  void _onHceDeactivation(HceDeactivationReason reason) {
    debugPrint('HCE Deactivated: ${reason.description}');
    _setTransactionActiveQuietly(false);
    // No notificar aquí, es solo desactivación
  }

  void _onHceError(HceException error) {
    debugPrint('HCE Error: ${error.toString()}');
    _setErrorQuietly('Error HCE: ${error.message}');
    _setTransactionActiveQuietly(false);
    // No notificar en errores
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
