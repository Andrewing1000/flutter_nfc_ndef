import 'app_layer/file_access/serializers/apdu_command_serializer.dart';
import 'app_layer/file_access/serializers/apdu_response_serializer.dart';

/// Callback function for HCE transaction events
typedef HceTransactionCallback = void Function(
    ApduCommand command, ApduResponse response);

/// Callback function for HCE deactivation events
typedef HceDeactivationCallback = void Function(HceDeactivationReason reason);

/// Callback function for HCE errors
typedef HceErrorCallback = void Function(HceException error);

/// Reasons for HCE deactivation
enum HceDeactivationReason {
  link(0, 'Link lost'),
  protocol(1, 'Protocol error'),
  rf(2, 'RF field lost');

  const HceDeactivationReason(this.code, this.description);

  final int code;
  final String description;

  static HceDeactivationReason fromCode(int code) {
    return HceDeactivationReason.values.firstWhere(
      (reason) => reason.code == code,
      orElse: () => HceDeactivationReason.rf,
    );
  }
}

/// Exception thrown when HCE operations fail
class HceException implements Exception {
  final String message;
  final String? code;

  const HceException(this.message, {this.code});

  @override
  String toString() =>
      code != null ? 'HceException($code): $message' : 'HceException: $message';
}
