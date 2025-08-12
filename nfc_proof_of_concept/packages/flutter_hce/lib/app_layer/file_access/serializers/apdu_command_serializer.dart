import 'dart:typed_data';

import '../../field.dart';
import '../fields/command_fields.dart';

abstract class ApduCommand extends ApduSerializer {
  final ApduParams params;
  final ApduClass cla;
  final ApduInstruction ins;

  ApduCommand._internal({
    required this.cla,
    required this.ins,
    required super.name,
    required this.params,
  });

  /// Smart factory constructor that builds appropriate command based on CLA, INS and params
  /// Follows the intelligent constructor philosophy from other serializers
  factory ApduCommand({
    ApduClass? cla,
    required ApduInstruction ins,
    required ApduParams params,
    ApduLc? lc,
    ApduData? data,
    ApduLe? le,
  }) {
    // Default to standard class if not provided
    final effectiveCla = cla ?? ApduClass.standard;

    if (ins == ApduInstruction.select) {
      if (data == null) {
        throw ArgumentError('SELECT command requires data field');
      }
      return SelectCommand._internal(
        cla: effectiveCla,
        params: params,
        data: data,
        lc: lc ?? ApduLc(lc: data.length),
      );
    } else if (ins == ApduInstruction.readBinary) {
      if (le == null) {
        throw ArgumentError('READ BINARY command requires Le field');
      }
      return ReadBinaryCommand._internal(
        cla: effectiveCla,
        params: params,
        le: le,
      );
    } else if (ins == ApduInstruction.updateBinary) {
      if (data == null) {
        throw ArgumentError('UPDATE BINARY command requires data field');
      }
      return UpdateBinaryCommand._internal(
        cla: effectiveCla,
        params: params,
        data: data,
        lc: lc ?? ApduLc(lc: data.length),
      );
    } else {
      return UnknownCommand._internal(
        cla: effectiveCla,
        ins: ins,
        params: params,
        data: data,
      );
    }
  }

  /// Deserializer factory - for parsing raw bytes only
  factory ApduCommand.fromBytes(Uint8List rawCommand) {
    if (rawCommand.length < 4) {
      throw ArgumentError(
          'Invalid APDU command: must be at least 4 bytes long. Got ${rawCommand.length} bytes.');
    }

    final instruction = ApduInstruction(rawCommand[1]);

    // Use == comparison with static final instances
    if (instruction == ApduInstruction.select) {
      return SelectCommand._fromBytes(rawCommand);
    } else if (instruction == ApduInstruction.readBinary) {
      return ReadBinaryCommand._fromBytes(rawCommand);
    } else if (instruction == ApduInstruction.updateBinary) {
      return UpdateBinaryCommand._fromBytes(rawCommand);
    } else {
      return UnknownCommand._fromBytes(rawCommand);
    }
  }
}

class SelectCommand extends ApduCommand {
  final ApduLc lc;
  final ApduData data;

  SelectCommand._internal({
    required super.cla,
    required super.params,
    required this.lc,
    required this.data,
  }) : super._internal(
          ins: ApduInstruction.select,
          name: "SELECT Command",
        );

  SelectCommand({
    required List<int> fileId,
    bool byName = false,
    ApduClass? cla,
  }) : this._internal(
          cla: cla ?? ApduClass.standard,
          params: byName ? ApduParams.byName : ApduParams.byFileId,
          data: ApduData(Uint8List.fromList(fileId), name: "File ID"),
          lc: ApduLc(lc: fileId.length), // Auto-calculate Lc
        );

  SelectCommand.byName({
    required List<int> applicationId,
    ApduClass? cla,
  }) : this(
          fileId: applicationId,
          byName: true,
          cla: cla,
        );

  SelectCommand.byFileId({
    required List<int> fileId,
    ApduClass? cla,
  }) : this(
          fileId: fileId,
          byName: false,
          cla: cla,
        );

  /// SELECT Capability Container file
  SelectCommand.capabilityContainer({ApduClass? cla})
      : this.byFileId(
          fileId: [0xE1, 0x03],
          cla: cla,
        );

  /// SELECT NDEF Data file
  SelectCommand.ndefFile({ApduClass? cla})
      : this.byFileId(
          fileId: [0xE1, 0x04],
          cla: cla,
        );

  // Deserialization factory
  factory SelectCommand._fromBytes(Uint8List rawCommand) {
    if (rawCommand.length < 5) {
      throw ArgumentError(
          'Invalid SELECT command frame: expected at least 5 bytes, got ${rawCommand.length}.');
    }
    final int lcValue = rawCommand[4];
    if (rawCommand.length != 5 + lcValue) {
      throw ArgumentError(
          'Invalid SELECT command frame: Lc value of $lcValue does not match data length of ${rawCommand.length - 5}.');
    }

    return SelectCommand._internal(
      cla: ApduClass.standard,
      params: ApduParams(p1: rawCommand[2], p2: rawCommand[3]),
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
  final ApduLe le;

  int get offset => (params.buffer[0] << 8) | params.buffer[1];
  int get lengthToRead => le.buffer[0];

  ReadBinaryCommand._internal({
    required super.cla,
    required super.params,
    required this.le,
  }) : super._internal(
          ins: ApduInstruction.readBinary,
          name: "READ BINARY Command",
        );

  /// Intelligent constructor - minimal arguments, deduces context
  ReadBinaryCommand({
    int offset = 0,
    int length = 255,
    ApduClass? cla,
  }) : this._internal(
          cla: cla ?? ApduClass.standard,
          params: ApduParams.forOffset(offset),
          le: ApduLe(le: length),
        );

  // Named constructors for common scenarios

  /// Read from beginning of file
  ReadBinaryCommand.fromStart({
    int length = 255,
    ApduClass? cla,
  }) : this(
          offset: 0,
          length: length,
          cla: cla,
        );

  /// Read NDEF length field (first 2 bytes)
  ReadBinaryCommand.ndefLength({ApduClass? cla})
      : this.fromStart(
          length: 2,
          cla: cla,
        );

  /// Read Capability Container (typical 15 bytes)
  ReadBinaryCommand.capabilityContainer({ApduClass? cla})
      : this.fromStart(
          length: 15,
          cla: cla,
        );

  /// Read in chunks for large files
  ReadBinaryCommand.chunk({
    required int offset,
    int chunkSize = 240,
    ApduClass? cla,
  }) : this(
          offset: offset,
          length: chunkSize,
          cla: cla,
        );

  // Deserialization factory
  factory ReadBinaryCommand._fromBytes(Uint8List rawCommand) {
    if (rawCommand.length != 5) {
      throw ArgumentError(
          'Invalid READ BINARY command frame: expected exactly 5 bytes, got ${rawCommand.length}.');
    }
    return ReadBinaryCommand._internal(
      cla: ApduClass.standard,
      params: ApduParams(p1: rawCommand[2], p2: rawCommand[3]),
      le: ApduLe(le: rawCommand[4]),
    );
  }

  @override
  void setFields() {
    fields = [cla, ins, params, le];
  }
}

class UpdateBinaryCommand extends ApduCommand {
  final ApduLc lc;
  final ApduData data;

  int get offset => (params.buffer[0] << 8) | params.buffer[1];
  Uint8List get dataToWrite => data.buffer;

  UpdateBinaryCommand._internal({
    required super.cla,
    required super.params,
    required this.lc,
    required this.data,
  }) : super._internal(
          ins: ApduInstruction.updateBinary,
          name: "UPDATE BINARY Command",
        );

  /// Intelligent constructor - minimal arguments, deduces context
  UpdateBinaryCommand({
    required List<int> data,
    int offset = 0,
    ApduClass? cla,
  }) : this._internal(
          cla: cla ?? ApduClass.standard,
          params: ApduParams.forOffset(offset),
          data: ApduData(Uint8List.fromList(data), name: "Update Data"),
          lc: ApduLc(lc: data.length), // Auto-calculate Lc
        );

  // Named constructors for common scenarios

  /// Update from beginning of file
  UpdateBinaryCommand.fromStart({
    required List<int> data,
    ApduClass? cla,
  }) : this(
          data: data,
          offset: 0,
          cla: cla,
        );

  /// Update NDEF data (includes length field)
  UpdateBinaryCommand.ndefData({
    required List<int> ndefRecords,
    ApduClass? cla,
  }) : this.fromStart(
          data: [
            // Length field (big-endian)
            (ndefRecords.length >> 8) & 0xFF,
            ndefRecords.length & 0xFF,
            // NDEF records
            ...ndefRecords,
          ],
          cla: cla,
        );

  /// Update in chunks for large data
  UpdateBinaryCommand.chunk({
    required List<int> data,
    required int offset,
    ApduClass? cla,
  }) : this(
          data: data,
          offset: offset,
          cla: cla,
        );

  // Deserialization factory
  factory UpdateBinaryCommand._fromBytes(Uint8List rawCommand) {
    if (rawCommand.length < 5) {
      throw ArgumentError(
          'Invalid UPDATE BINARY command frame: expected at least 5 bytes, got ${rawCommand.length}.');
    }
    final int lcValue = rawCommand[4];
    if (rawCommand.length != 5 + lcValue) {
      throw ArgumentError(
          'Invalid UPDATE BINARY command frame: Lc value of $lcValue does not match data length of ${rawCommand.length - 5}.');
    }

    return UpdateBinaryCommand._internal(
      cla: ApduClass.standard,
      params: ApduParams(p1: rawCommand[2], p2: rawCommand[3]),
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

  UnknownCommand._internal({
    required super.cla,
    required super.ins,
    required super.params,
    this.data,
  }) : super._internal(
          name: "Unknown Command",
        );

  // Deserialization factory
  factory UnknownCommand._fromBytes(Uint8List rawCommand) {
    return UnknownCommand._internal(
      cla: ApduClass.standard, // Assumed
      ins: ApduInstruction(rawCommand[1]),
      params: ApduParams(p1: rawCommand[2], p2: rawCommand[3]),
      data: rawCommand.length > 4
          ? ApduData(rawCommand.sublist(4), name: "Unknown Data")
          : null,
    );
  }

  @override
  void setFields() {
    fields = [cla, ins, params, data];
  }
}
