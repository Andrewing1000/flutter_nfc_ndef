import '../../field.dart';
import '../fields/capability_container_fields.dart';
import 'tlv_block_serializer.dart';

class CapabilityContainer extends ApduSerializer {
  late final CcLenField cclen;
  final CcMappingVersionField version = CcMappingVersionField.v2_0;
  final CcMaxApduDataSizeField mLe;
  final CcMaxApduDataSizeField mLc;
  final List<FileControlTlv> fileDescriptors;

  CapabilityContainer({
    required this.fileDescriptors,
    int? maxResponseSize,
    int? maxCommandSize,
  })  : mLe = CcMaxApduDataSizeField.mLe(maxResponseSize ?? 0x00FF),
        mLc = CcMaxApduDataSizeField.mLc(maxCommandSize ?? 0x00FF),
        super(name: "Capability Container") {
    if (fileDescriptors.isEmpty) {
      throw ArgumentError('CapabilityContainer must have at least one file descriptor.');
    }
  }

  @override
  void setFields() {
    int totalTlvLength = 0;
    for (final descriptor in fileDescriptors) {
      totalTlvLength += descriptor.length;
    }
    
    // Header is 7 bytes: CLEN(2) + Version(1) + MLe(2) + MLc(2)
    final int totalLength = 7 + totalTlvLength;
    cclen = CcLenField(totalLength);

    fields = [
      cclen,
      version,
      mLe,
      mLc,
      ...fileDescriptors,
    ];
  }
}