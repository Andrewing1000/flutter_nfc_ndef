import 'dart:math';
import 'dart:typed_data';
import 'dart:async';

import 'file_access/serializers/tlv_block_serializer.dart';
import 'file_access/fields/command_fields.dart';
import 'file_access/fields/response_fields.dart';
import 'file_access/serializers/apdu_command_serializer.dart';
import 'file_access/serializers/apdu_response_serializer.dart';
import 'file_access/serializers/capability_container_serializer.dart';
import 'ndef_format/serializers/ndef_message_serializer.dart';

enum _HceState {
  idle,
  appSelected,
  ccSelected,
  ndefSelected,
}

class _NdefFile {
  late Uint8List _bytes;
  final int maxSize;
  bool _inWriteSession = false;
  final List<int> _stagedPayload = <int>[];

  Uint8List get buffer => _bytes;
  int get currentSize => _bytes.length;

  _NdefFile({required NdefMessageSerializer message, required this.maxSize}) {
    _bytes = _buildBytes(message);
  }

  Uint8List _buildBytes(NdefMessageSerializer message) {
    final messageBytes = message.buffer;
    final nlen = messageBytes.length;

    if (nlen + 2 > maxSize) {
      throw ArgumentError(
          'NDEF message size ($nlen bytes) exceeds the max file size ($maxSize bytes) defined in the CC.');
    }

    final result = Uint8List(2 + messageBytes.length);
    result[0] = (nlen >> 8) & 0xFF;
    result[1] = nlen & 0xFF;
    result.setRange(2, result.length, messageBytes);
    return result;
  }

  void update(NdefMessageSerializer message) {
    _bytes = _buildBytes(message);
    _inWriteSession = false;
    _stagedPayload.clear();
  }

  void beginWriteSession() {
    // Set NLEN=0 to mark file as empty during write, per NFC Forum Type 4
    _bytes = Uint8List.fromList([0x00, 0x00]);
    _inWriteSession = true;
    _stagedPayload.clear();
  }

  bool writeData(int offset, Uint8List data) {
    if (!_inWriteSession) return false;
    if (offset < 2) return false; // Only NLEN is at 0..1; data must go at >=2
    final payloadOffset = offset - 2;
    final endIndex = payloadOffset + data.length;
    if (2 + endIndex > maxSize) return false;

    // Ensure capacity
    if (_stagedPayload.length < endIndex) {
      final toAdd = endIndex - _stagedPayload.length;
      _stagedPayload.addAll(List<int>.filled(toAdd, 0));
    }

    for (int i = 0; i < data.length; i++) {
      _stagedPayload[payloadOffset + i] = data[i];
    }
    return true;
  }

  bool finalizeWrite(int nlen) {
    if (!_inWriteSession) return false;
    if (nlen < 0 || 2 + nlen > maxSize) return false;
    if (_stagedPayload.length < nlen) return false;

    final result = Uint8List(2 + nlen);
    result[0] = (nlen >> 8) & 0xFF;
    result[1] = nlen & 0xFF;
    result.setRange(2, result.length, _stagedPayload.take(nlen));

    _bytes = result;
    _inWriteSession = false;
    _stagedPayload.clear();
    return true;
  }
}

class HceStateMachine {
  _HceState _currentState = _HceState.idle;

  final Uint8List aid;
  final CapabilityContainer capabilityContainer;
  final _NdefFile ndefFile;
  final bool isWritable;

  // Standard NDEF AID per NFC Forum specification
  static final ndefAid =
      Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);

  HceStateMachine({
    Uint8List? aid,
    required NdefMessageSerializer initialMessage,
    bool isWritable = false,
    int maxNdefFileSize = 2048, // 2KB
  })  : aid = aid ?? ndefAid,
        isWritable = isWritable,
        capabilityContainer = CapabilityContainer(
          fileDescriptors: [
            FileControlTlv.ndef(
              maxNdefFileSize: maxNdefFileSize,
              isNdefWritable: isWritable,
            ),
          ],
        ),
        ndefFile = _NdefFile(message: initialMessage, maxSize: maxNdefFileSize);

  /// Resets the state machine to its initial state.
  /// Call this when the NFC field is deactivated.
  void onDeactivated() {
    _currentState = _HceState.idle;
  }

  /// The main entry point for processing an incoming APDU command.
  /// Takes a raw command and returns a raw response.
  Future<Uint8List> processCommand(Uint8List rawCommand) async {
    try {
      final command = ApduCommand.fromBytes(rawCommand);
      final response = await _handleCommand(command);
      return response.buffer;
    } catch (_) {
      // Return generic error response for any parsing or processing failures
      return ApduResponse.error(ApduStatusWord.fromBytes(0x6F, 0x00)).buffer;
    }
  }

  /// The core FSM logic. Routes commands based on the current state.
  Future<ApduResponse> _handleCommand(ApduCommand command) async {
    switch (_currentState) {
      case _HceState.idle:
        return _handleIdleState(command);
      case _HceState.appSelected:
        return _handleAppSelectedState(command);
      case _HceState.ccSelected:
        return _handleCcSelectedState(command);
      case _HceState.ndefSelected:
        return _handleNdefSelectedState(command);
    }
  }

  ApduResponse _handleIdleState(ApduCommand command) {
    if (command is SelectCommand) {
      if (command.params == ApduParams.byName) {
        if (_isNdefAid(command.data.buffer)) {
          _currentState = _HceState.appSelected;
          return ApduResponse.success();
        } else {
          return ApduResponse.error(ApduStatusWord.fileNotFound);
        }
      }
      return ApduResponse.error(ApduStatusWord.wrongP1P2);
    }
    return ApduResponse.error(ApduStatusWord.insNotSupported);
  }

  ApduResponse _handleAppSelectedState(ApduCommand command) {
    if (command is SelectCommand) {
      if (command.params != ApduParams.byFileId) {
        return ApduResponse.error(ApduStatusWord.wrongP1P2);
      }
      final data = command.data.buffer;
      if (data.length < 2) {
        return ApduResponse.error(ApduStatusWord.wrongLength);
      }

      final fileId = (data[0] << 8) | data[1];
      switch (fileId) {
        case 0xE103: // CC File
          _currentState = _HceState.ccSelected;
          return ApduResponse.success();
        case 0xE104: // NDEF File
          _currentState = _HceState.ndefSelected;
          return ApduResponse.success();
        default:
          return ApduResponse.error(ApduStatusWord.fileNotFound);
      }
    }
    return ApduResponse.error(ApduStatusWord.insNotSupported);
  }

  ApduResponse _handleCcSelectedState(ApduCommand command) {
    switch (command.runtimeType) {
      case ReadBinaryCommand:
        return _processRead(
            command as ReadBinaryCommand, capabilityContainer.buffer);
      case SelectCommand:
        return _handleAppSelectedState(command); // allow re-selecting files
      case UpdateBinaryCommand:
        return ApduResponse.error(ApduStatusWord.conditionsNotSatisfied);
      default:
        return ApduResponse.error(ApduStatusWord.insNotSupported);
    }
  }

  ApduResponse _handleNdefSelectedState(ApduCommand command) {
    switch (command.runtimeType) {
      case ReadBinaryCommand:
        return _processRead(command as ReadBinaryCommand, ndefFile.buffer);
      case UpdateBinaryCommand:
        return _processUpdate(command as UpdateBinaryCommand);
      case SelectCommand:
        return _handleAppSelectedState(
            command); // allow switching between files
      default:
        return ApduResponse.error(ApduStatusWord.insNotSupported);
    }
  }

  ApduResponse _processRead(ReadBinaryCommand command, Uint8List file) {
    final offset = command.offset;
    if (offset >= file.length) {
      return ApduResponse.error(ApduStatusWord.wrongOffset);
    }

    final lengthToRead = command.lengthToRead == 0 ? 256 : command.lengthToRead;
    if (lengthToRead > 256) {
      return ApduResponse.error(ApduStatusWord.wrongLength);
    }

    final bytesRemaining = file.length - offset;
    final bytesToSend = min(lengthToRead, bytesRemaining);

    final chunk = file.sublist(offset, offset + bytesToSend);
    return ApduResponse.success(data: chunk);
  }

  ApduResponse _processUpdate(UpdateBinaryCommand command) {
    try {
      if (!isWritable) {
        return ApduResponse.error(ApduStatusWord.conditionsNotSatisfied);
      }

      final offset = command.offset;
      final data = command.dataToWrite;

      if (offset == 0) {
        if (data.length != 2) {
          return ApduResponse.error(ApduStatusWord.wrongLength);
        }
        final nlen = (data[0] << 8) | data[1];
        if (nlen == 0) {
          ndefFile.beginWriteSession();
          return ApduResponse.success();
        } else {
          final ok = ndefFile.finalizeWrite(nlen);
          return ok
              ? ApduResponse.success()
              : ApduResponse.error(ApduStatusWord.wrongLength);
        }
      }
      if (offset == 1) {
        // Partial NLEN writes are not allowed
        return ApduResponse.error(ApduStatusWord.wrongP1P2);
      }
      // Data area write
      final ok = ndefFile.writeData(offset, data);
      return ok
          ? ApduResponse.success()
          : ApduResponse.error(ApduStatusWord.conditionsNotSatisfied);
    } catch (_) {
      return ApduResponse.error(ApduStatusWord.fromBytes(0x6F, 0x00));
    }
  }

  bool _isNdefAid(Uint8List aidToCheck) {
    if (aidToCheck.length != aid.length) return false;
    for (int i = 0; i < aidToCheck.length; i++) {
      if (aidToCheck[i] != aid[i]) return false;
    }
    return true;
  }
}
