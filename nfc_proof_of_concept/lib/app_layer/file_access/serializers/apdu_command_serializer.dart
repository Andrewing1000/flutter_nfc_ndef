import 'dart:typed_data';

import '../../field.dart';
import '../fields/command_fields.dart';

abstract class ApduCommand extends ApduSerializer {
  final ApduClass cla;
  final ApduInstruction ins;

  ApduCommand._internal({
    required this.cla,
    required this.ins,
    required super.name,
  });
  
  factory ApduCommand.fromBytes(Uint8List rawCommand) {
    if (rawCommand.length < 4) {
      throw ArgumentError('Invalid APDU command: must be at least 4 bytes long. Got ${rawCommand.length} bytes.');
    }

    final int insByte = rawCommand[1];
    switch (insByte) {
      case ApduInstruction.SELECT_BYTE:
        return SelectCommand._fromBytes(rawCommand);
      case ApduInstruction.READ_BINARY_BYTE:
        return ReadBinaryCommand._fromBytes(rawCommand);
      case ApduInstruction.UPDATE_BINARY_BYTE:
        return UpdateBinaryCommand._fromBytes(rawCommand);
      default:
        return UnknownCommand.fromBytes(rawCommand);
    }
  }
}

class SelectCommand extends ApduCommand {
  final ApduParams params;
  final ApduLc lc;
  final ApduData data;

  SelectCommand._internal({
    required this.params,
    required this.lc,
    required this.data,
  }) : super._internal(cla: ApduClass.standard, ins: ApduInstruction.select, name: "SELECT Command");

  factory SelectCommand._fromBytes(Uint8List rawCommand) {
    if (rawCommand.length < 5) {
      throw ArgumentError('Invalid SELECT command frame: expected at least 5 bytes, got ${rawCommand.length}.');
    }
    final int lcValue = rawCommand[4];
    if (rawCommand.length != 5 + lcValue) {
      throw ArgumentError('Invalid SELECT command frame: Lc value of $lcValue does not match data length of ${rawCommand.length - 5}.');
    }

    return SelectCommand._internal(
      params: ApduParams(p1: rawCommand[2], p2: rawCommand[3], name: "P1-P2 (Parsed)"),
      lc: ApduLc(lc: lcValue),
      data: ApduData(rawCommand.sublist(5, 5 + lcValue), name: "Data (Parsed)"),
    );
  }

  @override
  void setFields() {
    fields = [cla, ins, params, lc, data];
  }
}

class ReadBinaryCommand extends ApduCommand {
  final ApduParams params;
  final ApduLe le;
  
  int get offset => (params.buffer[0] << 8) | params.buffer[1];
  int get lengthToRead => le.buffer[0];

  ReadBinaryCommand._internal({required this.params, required this.le})
      : super._internal(cla: ApduClass.standard, ins: ApduInstruction.readBinary, name: "READ BINARY Command");

  factory ReadBinaryCommand._fromBytes(Uint8List rawCommand) {
    if (rawCommand.length != 5) {
      throw ArgumentError('Invalid READ BINARY command frame: expected exactly 5 bytes, got ${rawCommand.length}.');
    }
    return ReadBinaryCommand._internal(
      params: ApduParams(p1: rawCommand[2], p2: rawCommand[3], name: "P1-P2 (Parsed)"),
      le: ApduLe(le: rawCommand[4]),
    );
  }

  @override
  void setFields() {
    fields = [cla, ins, params, le];
  }
}

class UpdateBinaryCommand extends ApduCommand {
  final ApduParams params;
  final ApduLc lc;
  final ApduData data;

  int get offset => (params.buffer[0] << 8) | params.buffer[1];
  Uint8List get dataToWrite => data.buffer;

  UpdateBinaryCommand._internal({required this.params, required this.lc, required this.data})
      : super._internal(cla: ApduClass.standard, ins: ApduInstruction.updateBinary, name: "UPDATE BINARY Command");

  factory UpdateBinaryCommand._fromBytes(Uint8List rawCommand) {
    if (rawCommand.length < 5) {
      throw ArgumentError('Invalid UPDATE BINARY command frame: expected at least 5 bytes, got ${rawCommand.length}.');
    }
    final int lcValue = rawCommand[4];
    if (rawCommand.length != 5 + lcValue) {
      throw ArgumentError('Invalid UPDATE BINARY command frame: Lc value of $lcValue does not match data length of ${rawCommand.length - 5}.');
    }
    
    return UpdateBinaryCommand._internal(
      params: ApduParams(p1: rawCommand[2], p2: rawCommand[3], name: "P1-P2 (Parsed)"),
      lc: ApduLc(lc: lcValue),
      data: ApduData(rawCommand.sublist(5, 5 + lcValue), name: "Data (Parsed)"),
    );
  }

  @override
  void setFields() {
    fields = [cla, ins, params, lc, data];
  }
}

class UnknownCommand extends ApduCommand {
  final ApduData? data;

  UnknownCommand.fromBytes(Uint8List rawCommand) 
    : data = rawCommand.length > 4 ? ApduData(rawCommand.sublist(4), name: "Unknown Data") : null,
      super._internal(
        cla: ApduClass.standard, // Assumed
        ins: ApduInstruction(rawCommand[1], name: "INS (Unknown)"),
        name: "Unknown Command"
      );

  @override
  void setFields() {
    fields = [cla, ins, data];
  }
}