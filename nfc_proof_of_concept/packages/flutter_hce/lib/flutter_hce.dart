// Public entrypoint for the flutter_hce plugin.
// Export the primary API surface used by applications.

export 'hce_manager.dart';
export 'hce_types.dart';
export 'hce_utils.dart';

// Common serializers that app code may use to build NDEF/APDU payloads.
export 'app_layer/file_access/serializers/apdu_command_serializer.dart';
export 'app_layer/file_access/serializers/apdu_response_serializer.dart';
export 'app_layer/ndef_format/serializers/ndef_record_serializer.dart';
