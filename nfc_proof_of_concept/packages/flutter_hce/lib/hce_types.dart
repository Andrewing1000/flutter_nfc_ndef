import 'app_layer/file_access/serializers/apdu_command_serializer.dart';
import 'app_layer/file_access/serializers/apdu_response_serializer.dart';

typedef HceTransactionCallback = void Function(
    ApduCommand command, ApduResponse response);

typedef HceDeactivationCallback = void Function(HceDeactivationReason reason);

typedef HceErrorCallback = void Function(HceException error);

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

class HceException implements Exception {
  final String message;
  final String? code;

  const HceException(this.message, {this.code});

  @override
  String toString() =>
      code != null ? 'HceException($code): $message' : 'HceException: $message';
}
