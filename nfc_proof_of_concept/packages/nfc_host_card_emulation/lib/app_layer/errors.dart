class HceException implements Exception {
  final String message;
  final String? details;
  final HceErrorCode code;

  HceException(this.code, this.message, {this.details});

  @override
  String toString() {
    if (details != null) {
      return 'HceException: [$code] $message\nDetails: $details';
    }
    return 'HceException: [$code] $message';
  }
}

enum HceErrorCode {
  // Initialization Errors
  invalidAid,
  serviceNotAvailable,

  // State Machine Errors
  invalidState,
  invalidTransition,
  powerLoss,
  bufferOverflow,

  // NDEF Errors
  invalidNdefFormat,
  messageTooLarge,
  invalidChunkSequence,

  // File System Errors
  fileNotFound,
  invalidFileId,
  fileAccessDenied,

  // Communication Errors
  connectionLost,
  responseTimeout,

  // Resource Errors
  outOfMemory,

  // Unknown Errors
  unknown
}
