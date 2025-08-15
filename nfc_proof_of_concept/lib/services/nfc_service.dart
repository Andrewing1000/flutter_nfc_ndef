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

/// Pure callback-based NFC service without ChangeNotifier
/// Supports both HCE (Host Card Emulation) and NFC Manager modes
class NfcService {
  bool _isReady = false;
  bool _isChecking = false;
  bool _isTransactionActive = false;
  NfcBarMode? _currentMode;
  String? _lastError;
  Map<String, dynamic>? _lastReadMessage;

  bool _nfcSessionActive = false;
  FlutterHceManager? _hceManager;
  NdefReaderService? _ndefReader;

  bool get isReady => _isReady;
  bool get isChecking => _isChecking;
  bool get isTransactionActive => _isTransactionActive;
  NfcBarMode? get currentMode => _currentMode;
  String? get lastError => _lastError;
  Map<String, dynamic>? get lastReadMessage => _lastReadMessage;

  final void Function()? onDiscovered;
  final void Function(Map<String, dynamic>)? onRead;
  final void Function(String error)? onReadError;
  final void Function()? onDelivered;
  final void Function(ApduCommand command, ApduResponse response)? onFileAccess;

  NfcService({
    this.onDiscovered,
    this.onRead,
    this.onReadError,
    this.onDelivered,
    this.onFileAccess,
  });

  Future<bool> checkNfcState({
    String? broadcastData,
    NfcBarMode? mode,
    required Uint8List aid,
  }) async {
    if (_isChecking) return _isReady;

    _setChecking(true);
    _clearErrorQuietly();

    try {
      final isNfcAvailable = await NfcManager.instance.isAvailable();

      if (!isNfcAvailable) {
        _setReadyQuietly(false);
        return false;
      }

      if (mode == NfcBarMode.broadcastOnly) {
        return await _initializeHceMode(broadcastData, aid);
      } else if (mode == NfcBarMode.readOnly) {
        return await _initializeReadMode(aid);
      } else {
        _setErrorQuietly('Modo o AID no especificados correctamente');
        _setReadyQuietly(false);
        return false;
      }
    } catch (e) {
      _setErrorQuietly('Error al inicializar NFC: $e');
      _setReadyQuietly(false);
      return false;
    } finally {
      _setChecking(false);
    }
  }

  Future<bool> _initializeHceMode(String? broadcastData, Uint8List aid) async {
    try {
      await _stopAll();

      _hceManager = FlutterHceManager.instance;
      final nfcState = await _hceManager!.checkNfcState();
      debugPrint('NFC State: ${nfcState.description}');

      if (nfcState != NfcState.enabled) {
        _setErrorQuietly('NFC no está habilitado en este dispositivo');
        return false;
      }

      _setCurrentModeQuietly(NfcBarMode.broadcastOnly);
      _setReadyQuietly(true);

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

      print("llegamos aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
      print(aid);
      print(broadcastData);

      final success = await _hceManager!.initialize(
        aid: aid,
        records: records,
        isWritable: false,
        maxNdefFileSize: 4096,
        onTransaction: _onHceTransaction,
        onDeactivation: _onHceDeactivation,
        onError: _onHceError,
      );

      if (success) {
        debugPrint(
            'HCE initialized successfully with AID: ${AidUtils.formatAid(aid)}');
        return true;
      } else {
        _setErrorQuietly('No se pudo inicializar HCE');
        _setReadyQuietly(false);
        return false;
      }
    } catch (e) {
      _setErrorQuietly('Error en modo HCE: $e');
      _setReadyQuietly(false);
      debugPrint('HCE Error: $e');
      return false;
    }
  }

  Future<bool> _initializeReadMode(Uint8List aid) async {
    try {
      await _stopAll();

      // Initialize the NdefReaderService with the provided AID
      _ndefReader = NdefReaderService(aid: aid);

      _setCurrentModeQuietly(NfcBarMode.readOnly);
      _setReadyQuietly(true);

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          _setTransactionActiveQuietly(true);

          try {
            final ndefData = await _ndefReader?.readNdefFromTag(tag);
            if (ndefData != null) {
              debugPrint('NDEF Data read successfully: $ndefData');

              _lastReadMessage = ndefData;
              onRead?.call(_lastReadMessage!);
            } else {
              onReadError?.call('No NDEF data found or read failed');
              debugPrint('No NDEF data found or read failed');
              _lastReadMessage = null;
            }
          } catch (e) {
            debugPrint('Error reading NDEF data: $e');
            onReadError?.call('No NDEF data found or read failed');
            _setErrorQuietly('Error leyendo datos NDEF: $e');
            _lastReadMessage = null;
          } finally {
            Timer(const Duration(milliseconds: 1500), () {
              _setTransactionActiveQuietly(false);
            });
          }
        },
      );

      _nfcSessionActive = true;
      return true;
    } catch (e) {
      _setErrorQuietly('Error en modo lectura: $e');
      _setReadyQuietly(false);
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
    }
  }

  void _setReady(bool ready) {
    _isReady = ready;
  }

  void _setReadyQuietly(bool ready) {
    _isReady = ready;
  }

  void _setChecking(bool checking) {
    _isChecking = checking;
  }

  void _setCheckingQuietly(bool checking) {
    _isChecking = checking;
  }

  // Método público para controlar manualmente el estado de carga
  void setCheckingManually(bool checking) {
    _setChecking(checking);
  }

  void _setTransactionActive(bool active) {
    _isTransactionActive = active;
  }

  void _setTransactionActiveQuietly(bool active) {
    _isTransactionActive = active;
  }

  void _setCurrentMode(NfcBarMode? mode) {
    _currentMode = mode;
  }

  void _setCurrentModeQuietly(NfcBarMode? mode) {
    _currentMode = mode;
  }

  void _setError(String? error) {
    _lastError = error;
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

  void clearLastReadMessage() {
    _lastReadMessage = null;
  }

  void reset() {
    _stopAll();
    _setReadyQuietly(false);
    _setCheckingQuietly(false);
    _setTransactionActiveQuietly(false);
    _setCurrentModeQuietly(null);
    _clearErrorQuietly();
    _lastReadMessage = null;
  }

  void _onHceTransaction(ApduCommand command, ApduResponse response) {
    debugPrint(
        'HCE Transaction: ${command.toString()} -> ${response.toString()}');

    onFileAccess?.call(command, response);

    if (command is SelectCommand && response.statusWord == ApduStatusWord.ok) {
      onDiscovered?.call();
    }

    if (command is ReadBinaryCommand &&
        response.statusWord == ApduStatusWord.ok) {
      onDelivered?.call();
    }

    _setTransactionActiveQuietly(true);

    Future.delayed(const Duration(seconds: 2), () {
      _setTransactionActiveQuietly(false);
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

  void dispose() {
    reset();
  }
}
