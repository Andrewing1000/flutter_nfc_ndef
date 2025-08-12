import 'dart:typed_data';

import '../file_access/serializers/apdu_command_serializer.dart';

/// High-level wrapper for APDU command creation and parsing
/// Uses intelligent constructors instead of manual byte manipulation
class ApduCommandParser {
  final ApduCommand _command;

  ApduCommandParser._(this._command);

  /// Creates a parser from raw command bytes (deserialization only)
  factory ApduCommandParser.fromBytes(Uint8List rawCommand) {
    final command = ApduCommand.fromBytes(rawCommand);
    return ApduCommandParser._(command);
  }

  /// Intelligent constructor - minimal arguments, deduces context
  ApduCommandParser({
    required List<int> fileId,
    bool byName = false,
  }) : this._(SelectCommand(fileId: fileId, byName: byName));

  // Named constructors for SELECT commands

  /// SELECT by Application Name (AID) - requires explicit AID
  ApduCommandParser.selectByName({
    required List<int> applicationId,
  }) : this._(SelectCommand.byName(applicationId: applicationId));

  /// SELECT by File ID
  ApduCommandParser.selectByFileId({
    required List<int> fileId,
  }) : this._(SelectCommand.byFileId(fileId: fileId));

  /// SELECT Capability Container file
  ApduCommandParser.selectCapabilityContainer()
      : this._(SelectCommand.capabilityContainer());

  /// SELECT NDEF Data file
  ApduCommandParser.selectNdefFile() : this._(SelectCommand.ndefFile());

  /// READ BINARY command with intelligent defaults
  ApduCommandParser.readBinary({
    int offset = 0,
    int length = 255,
  }) : this._(ReadBinaryCommand(offset: offset, length: length));

  /// Read from beginning of file
  ApduCommandParser.readFromStart({
    int length = 255,
  }) : this._(ReadBinaryCommand.fromStart(length: length));

  /// Read NDEF length field (first 2 bytes)
  ApduCommandParser.readNdefLength() : this._(ReadBinaryCommand.ndefLength());

  /// Read Capability Container (typical 15 bytes)
  ApduCommandParser.readCapabilityContainer()
      : this._(ReadBinaryCommand.capabilityContainer());

  /// Read in chunks for large files
  ApduCommandParser.readChunk({
    required int offset,
    int chunkSize = 240,
  }) : this._(ReadBinaryCommand.chunk(offset: offset, chunkSize: chunkSize));

  // Named constructors for UPDATE BINARY commands

  /// UPDATE BINARY command with intelligent defaults
  ApduCommandParser.updateBinary({
    required List<int> data,
    int offset = 0,
  }) : this._(UpdateBinaryCommand(data: data, offset: offset));

  /// Update from beginning of file
  ApduCommandParser.updateFromStart({
    required List<int> data,
  }) : this._(UpdateBinaryCommand.fromStart(data: data));

  /// Update NDEF data (includes length field)
  ApduCommandParser.updateNdefData({
    required List<int> ndefRecords,
  }) : this._(UpdateBinaryCommand.ndefData(ndefRecords: ndefRecords));

  /// Update in chunks for large data
  ApduCommandParser.updateChunk({
    required List<int> data,
    required int offset,
  }) : this._(UpdateBinaryCommand.chunk(data: data, offset: offset));

  // Convenient getters

  /// Returns the command type (select, read_binary, update_binary, unknown)
  String get commandType {
    if (_command is SelectCommand) return 'select';
    if (_command is ReadBinaryCommand) return 'read_binary';
    if (_command is UpdateBinaryCommand) return 'update_binary';
    return 'unknown';
  }

  /// Returns true if this is a SELECT command
  bool get isSelect => commandType == 'select';

  /// Returns true if this is a READ BINARY command
  bool get isReadBinary => commandType == 'read_binary';

  /// Returns true if this is an UPDATE BINARY command
  bool get isUpdateBinary => commandType == 'update_binary';

  /// Gets the file ID for SELECT commands
  Uint8List? get selectedFileId {
    if (_command is SelectCommand) {
      return (_command as SelectCommand).data.buffer;
    }
    return null;
  }

  /// Gets the offset for READ/UPDATE BINARY commands
  int? get binaryOffset {
    if (_command is ReadBinaryCommand) {
      return (_command as ReadBinaryCommand).offset;
    }
    if (_command is UpdateBinaryCommand) {
      return (_command as UpdateBinaryCommand).offset;
    }
    return null;
  }

  /// Gets the read length for READ BINARY commands
  int? get readLength {
    if (_command is ReadBinaryCommand) {
      return (_command as ReadBinaryCommand).lengthToRead;
    }
    return null;
  }

  /// Gets the data to write for UPDATE BINARY commands
  Uint8List? get dataToWrite {
    if (_command is UpdateBinaryCommand) {
      return (_command as UpdateBinaryCommand).dataToWrite;
    }
    return null;
  }

  /// Gets the underlying command serializer (for advanced use)
  ApduCommand get command => _command;

  /// Serializes to bytes for transmission
  Uint8List toBytes() {
    return _command.buffer;
  }

  /// Developer-friendly string representation
  @override
  String toString() {
    switch (commandType) {
      case 'select':
        final fileId = selectedFileId
            ?.map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join()
            .toUpperCase();
        return 'ApduCommandParser.select(0x$fileId)';
      case 'read_binary':
        return 'ApduCommandParser.readBinary(offset: $binaryOffset, length: $readLength)';
      case 'update_binary':
        return 'ApduCommandParser.updateBinary(${dataToWrite?.length} bytes, offset: $binaryOffset)';
      default:
        return 'ApduCommandParser.unknown()';
    }
  }

  /// JSON representation for debugging
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> base = {
      'type': commandType,
    };

    switch (commandType) {
      case 'select':
        base['file_id'] = selectedFileId?.toList();
        break;
      case 'read_binary':
        base['offset'] = binaryOffset;
        base['length'] = readLength;
        break;
      case 'update_binary':
        base['offset'] = binaryOffset;
        base['data_length'] = dataToWrite?.length;
        break;
    }

    return base;
  }
}
