import 'dart:math';
import 'dart:typed_data';

import 'file_access/fields/response_fields.dart';
import 'file_access/serializers/tlv_block_serializer.dart';
import 'file_access/fields/command_fields.dart';
import 'file_access/serializers/apdu_command_serializer.dart';
import 'file_access/serializers/apdu_response_serializer.dart';
import 'file_access/serializers/capability_container_serializer.dart';
import 'ndef_format/ndef_message_serializer.dart';


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
      throw ArgumentError('NDEF message size ($nlen bytes) exceeds the max file size ($maxSize bytes) defined in the CC.');
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
  static final ndefAid = Uint8List.fromList([0xA0, 0x00, 0xDA, 0xDA, 0xDA, 0xDA, 0xDA]);

  HceStateMachine({
    required NdefMessageSerializer initialMessage,
    bool isWritable = false,
    int maxNdefFileSize = 2048, // 2KB
  }) : capabilityContainer = CapabilityContainer(
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
  Uint8List processCommand(Uint8List rawCommand) {
    try {
      final command = ApduCommand.fromBytes(rawCommand);
      final response = _handleCommand(command);
      return response.buffer;
    } on ArgumentError catch (e) {
      // Error de parseo (trama malformada)
      print("APDU Parsing Error: $e");
      return ApduResponse.error(ApduStatusWord.wrongLength).buffer;
    } on UnimplementedError catch (e) {
      // INS no soportado
      print("Unsupported Instruction: $e");
      return ApduResponse.error(ApduStatusWord.insNotSupported).buffer;
    } catch (e) {
      // Error inesperado
      print("Unexpected FSM Error: $e");
      return ApduResponse.error(ApduStatusWord.conditionsNotSatisfied).buffer;
    }
  }

  /// The core FSM logic. Routes commands based on the current state.
  ApduResponse _handleCommand(ApduCommand command) {
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
      if (command.params == ApduParams.byName && _isNdefAid(command.data.buffer)) {
        _currentState = _HceState.appSelected;
        return ApduResponse.success();
      }
    }
    return ApduResponse.error(ApduStatusWord.conditionsNotSatisfied);
  }

  ApduResponse _handleAppSelectedState(ApduCommand command) {
    if (command is SelectCommand) {
      // En APP_SELECTED, solo aceptamos SELECT by File ID
      if (command.params == ApduParams.byFileId) {
        final fileId = (command.data!.buffer[0] << 8) | command.data!.buffer[1];
        if (fileId == 0xE103) { // CC File
          _currentState = _HceState.ccSelected;
          return ApduResponse.success();
        } else if (fileId == 0xE104) { // NDEF File
          _currentState = _HceState.ndefSelected;
          return ApduResponse.success();
        } else {
          return ApduResponse.error(ApduStatusWord.fileNotFound);
        }
      }
    }
    return ApduResponse.error(ApduStatusWord.conditionsNotSatisfied);
  }

  ApduResponse _handleCcSelectedState(ApduCommand command) {
    if (command is ReadBinaryCommand) {
      return _processRead(command, capabilityContainer.buffer);
    }
    return ApduResponse.error(ApduStatusWord.insNotSupported);
  }

  ApduResponse _handleNdefSelectedState(ApduCommand command) {
    if (command is ReadBinaryCommand) {
      return _processRead(command, ndefFile.buffer);
    }

    return ApduResponse.error(ApduStatusWord.insNotSupported);
  }


  ApduResponse _processRead(ReadBinaryCommand command, Uint8List file) {
    final offset = command.offset;
    if (offset >= file.length) {
      return ApduResponse.error(ApduStatusWord.wrongOffset);
    }
    
    final lengthToRead = command.lengthToRead == 0 ? 256 : command.lengthToRead;
    final bytesRemaining = file.length - offset;
    final bytesToSend = min(lengthToRead, bytesRemaining);

    final chunk = file.sublist(offset, offset + bytesToSend);
    return ApduResponse.success(data: chunk);
  }

  bool _isNdefAid(Uint8List? aid) {
    if (aid == null || aid.length != ndefAid.length) return false;
    for (int i = 0; i < aid.length; i++) {
      if (aid[i] != ndefAid[i]) return false;
    }
    return true;
  }
}