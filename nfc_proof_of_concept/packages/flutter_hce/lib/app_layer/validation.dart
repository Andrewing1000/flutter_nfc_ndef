import 'dart:typed_data';
import 'errors.dart';

class ValidationUtils {
  /// Validates an Application ID (AID) according to ISO/IEC 7816-4
  static void validateAid(Uint8List aid) {
    if (aid.length < 5 || aid.length > 16) {
      throw HceException(HceErrorCode.invalidAid,
          'AID length must be between 5 and 16 bytes.');
    }

    // Check RID (first 5 bytes) according to ISO/IEC 7816-4
    // RID is assigned by ISO/IEC 7816-4 registration authority
    if (aid[0] == 0x00 || aid[0] == 0xFF) {
      throw HceException(HceErrorCode.invalidAid,
          'Invalid RID: first byte cannot be 0x00 or 0xFF');
    }
  }

  /// Validates a file ID according to ISO/IEC 7816-4
  static void validateFileId(int fileId) {
    if (fileId < 0x0000 || fileId > 0xFFFF) {
      throw HceException(HceErrorCode.invalidFileId,
          'File ID must be between 0x0000 and 0xFFFF');
    }

    // Reserved file IDs according to ISO/IEC 7816-4
    if (fileId == 0x3F00 || fileId == 0x3FFF) {
      throw HceException(HceErrorCode.invalidFileId,
          'Invalid file ID: 0x3F00 and 0x3FFF are reserved');
    }
  }

  /// Validates NDEF message size
  static void validateNdefMessageSize(int size) {
    // According to NFC Forum Type 4 Tag specification
    if (size > 0xFFFE) {
      throw HceException(HceErrorCode.messageTooLarge,
          'NDEF message size cannot exceed 65534 bytes');
    }
  }
}
