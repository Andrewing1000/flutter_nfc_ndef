import 'dart:math';
import 'dart:typed_data';
import 'dart:async';

import 'errors.dart';
import 'file_access/serializers/tlv_block_serializer.dart';
import 'file_access/fields/command_fields.dart';
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

  Uint8List get buffer => _bytes;
  int get currentSize => _bytes.length;

  _NdefFile({required NdefMessageSerializer message, required this.maxSize}) {
    update(message);
  }

  void update(NdefMessageSerializer message) {
    final messageBytes = message.buffer;
    final nlen = messageBytes.length;

    if (nlen + 2 > maxSize) {
      throw ArgumentError(
          'NDEF message size ($nlen bytes) exceeds the max file size ($maxSize bytes) defined in the CC.');
    }

    final nlenBytes = Uint8List(2);
    nlenBytes[0] = (nlen >> 8) & 0xFF;
    nlenBytes[1] = nlen & 0xFF;

    _bytes = Uint8List.fromList(nlenBytes + messageBytes);
  }
}

class HceStateMachine {
  _HceState _currentState = _HceState.idle;

  final CapabilityContainer capabilityContainer;
  final _NdefFile ndefFile;

  // El AID estándar para la aplicación NDEF.
  static final ndefAid =
      Uint8List.fromList([0xA0, 0x00, 0xDA, 0xDA, 0xDA, 0xDA, 0xDA]);

  HceStateMachine({
    required NdefMessageSerializer initialMessage,
    bool isWritable = false,
    int maxNdefFileSize = 2048, // 2KB
  })  : capabilityContainer = CapabilityContainer(
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
    } on ArgumentError catch (e) {
      throw HceException(HceErrorCode.invalidNdefFormat, "APDU Parsing Error",
          details: e.toString());
    } on UnimplementedError catch (e) {
      throw HceException(HceErrorCode.invalidState, "Unsupported instruction",
          details: e.toString());
    } catch (e) {
      throw HceException(HceErrorCode.unknown, "Unexpected FSM error",
          details: e.toString());
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
      if (command.params == ApduParams.byName &&
          _isNdefAid(command.data.buffer)) {
        _currentState = _HceState.appSelected;
        return ApduResponse.success();
      }
    }
    throw HceException(
        HceErrorCode.invalidState, "Invalid command in IDLE state");
  }

  ApduResponse _handleAppSelectedState(ApduCommand command) {
    if (command is SelectCommand && command.params == ApduParams.byFileId) {
      final data = command.data.buffer;
      if (data.length < 2) {
        throw HceException(
            HceErrorCode.invalidFileId, "File ID must be 2 bytes");
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
          throw HceException(HceErrorCode.fileNotFound,
              "File ID 0x${fileId.toRadixString(16).padLeft(4, '0')} not found");
      }
    }
    throw HceException(
        HceErrorCode.invalidState, "Invalid command in APP_SELECTED state");
  }

  ApduResponse _handleCcSelectedState(ApduCommand command) {
    if (command is ReadBinaryCommand) {
      return _processRead(command, capabilityContainer.buffer);
    }
    throw HceException(HceErrorCode.invalidState,
        "Only READ_BINARY commands are allowed in CC_SELECTED state");
  }

  ApduResponse _handleNdefSelectedState(ApduCommand command) {
    if (command is ReadBinaryCommand) {
      return _processRead(command, ndefFile.buffer);
    }
    throw HceException(HceErrorCode.invalidState,
        "Only READ_BINARY commands are allowed in NDEF_SELECTED state");
  }

  ApduResponse _processRead(ReadBinaryCommand command, Uint8List file) {
    final offset = command.offset;
    if (offset >= file.length) {
      throw HceException(HceErrorCode.invalidState,
          "Read offset ${offset} exceeds file length ${file.length}");
    }

    final lengthToRead = command.lengthToRead == 0 ? 256 : command.lengthToRead;
    if (lengthToRead > 256) {
      throw HceException(HceErrorCode.bufferOverflow,
          "Requested length ${lengthToRead} exceeds maximum allowed (256 bytes)");
    }

    final bytesRemaining = file.length - offset;
    final bytesToSend = min(lengthToRead, bytesRemaining);

    final chunk = file.sublist(offset, offset + bytesToSend);
    return ApduResponse.success(data: chunk);
  }

  bool _isNdefAid(Uint8List aid) {
    if (aid.length != ndefAid.length) return false;
    for (int i = 0; i < aid.length; i++) {
      if (aid[i] != ndefAid[i]) return false;
    }
    return true;
  }
}
