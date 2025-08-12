import 'dart:typed_data';

import '../file_access/serializers/apdu_command_serializer.dart';

/// High-level wrapper for APDU command creation and parsing
/// Simplifies common NFC operations
class ApduCommandParser {
  final ApduCommand _command;

  ApduCommandParser._(this._command);

  /// Creates a parser from raw command bytes
  factory ApduCommandParser.fromBytes(Uint8List rawCommand) {
    final command = ApduCommand.fromBytes(rawCommand);
    return ApduCommandParser._(command);
  }

  /// Creates a SELECT command for NDEF application
  factory ApduCommandParser.selectNdefApplication() {
    // Standard NDEF Application ID: D2760000850101
    final ndefAppId = [0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01];
    return ApduCommandParser._buildSelect(ndefAppId);
  }

  /// Creates a SELECT command for Capability Container
  factory ApduCommandParser.selectCapabilityContainer() {
    // Standard CC file ID: E103
    final ccFileId = [0xE1, 0x03];
    return ApduCommandParser._buildSelect(ccFileId);
  }

  /// Creates a SELECT command for NDEF file
  factory ApduCommandParser.selectNdefFile() {
    // Standard NDEF file ID: E104
    final ndefFileId = [0xE1, 0x04];
    return ApduCommandParser._buildSelect(ndefFileId);
  }

  /// Creates a generic SELECT command
  factory ApduCommandParser.select(List<int> fileId) {
    return ApduCommandParser._buildSelect(fileId);
  }

  /// Creates a READ BINARY command
  factory ApduCommandParser.readBinary({int offset = 0, int length = 255}) {
    if (offset > 0x7FFF) throw ArgumentError('Offset too large');
    if (length > 255) throw ArgumentError('Length must be ≤ 255');

    final p1 = (offset >> 8) & 0xFF;
    final p2 = offset & 0xFF;

    // CLA | INS | P1 | P2 | Le
    final commandBytes = Uint8List.fromList([
      0x00, // CLA (standard)
      0xB0, // INS (READ BINARY)
      p1, // P1 (offset high byte)
      p2, // P2 (offset low byte)
      length, // Le (length to read)
    ]);

    final command = ApduCommand.fromBytes(commandBytes);
    return ApduCommandParser._(command);
  }

  /// Creates an UPDATE BINARY command
  factory ApduCommandParser.updateBinary(List<int> data, {int offset = 0}) {
    if (offset > 0x7FFF) throw ArgumentError('Offset too large');
    if (data.length > 255)
      throw ArgumentError('Data too large for single UPDATE');

    final p1 = (offset >> 8) & 0xFF;
    final p2 = offset & 0xFF;

    // CLA | INS | P1 | P2 | Lc | Data
    final commandBytes = <int>[
      0x00, // CLA (standard)
      0xD6, // INS (UPDATE BINARY)
      p1, // P1 (offset high byte)
      p2, // P2 (offset low byte)
      data.length, // Lc (data length)
    ];
    commandBytes.addAll(data);

    final command = ApduCommand.fromBytes(Uint8List.fromList(commandBytes));
    return ApduCommandParser._(command);
  }

  // Internal helper for building SELECT commands
  static ApduCommandParser _buildSelect(List<int> fileId) {
    // CLA | INS | P1 | P2 | Lc | Data
    final commandBytes = <int>[
      0x00, // CLA (standard)
      0xA4, // INS (SELECT)
      0x00, // P1 (select by file ID)
      0x0C, // P2 (return FCI template)
      fileId.length, // Lc (file ID length)
    ];
    commandBytes.addAll(fileId);

    final command = ApduCommand.fromBytes(Uint8List.fromList(commandBytes));
    return ApduCommandParser._(command);
  }

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
