import 'dart:convert';
import 'dart:typed_data';
import '../field.dart';


enum Tnf {
  empty(0x00),
  wellKnown(0x01), // WKT
  mediaType(0x02),
  absoluteUri(0x03),
  externalType(0x04), // EXT
  unknown(0x05),
  unchanged(0x06);

  final int value;
  const Tnf(this.value);
}

class NdefFlagByte extends ApduField {
  static const int _MB_MASK = 0x80;
  static const int _ME_MASK = 0x40;
  static const int _CF_MASK = 0x20;
  static const int _SR_MASK = 0x10;
  static const int _IL_MASK = 0x08;
  static const int _TNF_MASK = 0x07;

  bool get isMessageBegin => (buffer[0] & _MB_MASK) != 0;
  bool get isMessageEnd => (buffer[0] & _ME_MASK) != 0;
  bool get isChunked => (buffer[0] & _CF_MASK) != 0;
  bool get isShortRecord => (buffer[0] & _SR_MASK) != 0;
  bool get hasId => (buffer[0] & _IL_MASK) != 0;
  Tnf get tnf {
    final tnfValue = buffer[0] & _TNF_MASK;
    return Tnf.values.firstWhere((e) => e.value == tnfValue);
  }

  NdefFlagByte._internal(int flagByte) : super(size: 1, name: "Flags") {
    buffer[0] = flagByte;
  }
  
  factory NdefFlagByte.record({
    required Tnf tnf,
    required bool isShortRecord,
    bool hasId = false,
    bool isFirst = true,
    bool isLast = true,
  }) {
    int value = tnf.value;
    if (isFirst) value |= _MB_MASK;
    if (isLast) value |= _ME_MASK;
    if (isShortRecord) value |= _SR_MASK;
    if (hasId) value |= _IL_MASK;
    return NdefFlagByte._internal(value);
  }

  factory NdefFlagByte.chunk({
    Tnf? tnf, 
    bool isFirstChunk = false,
    bool isLastChunk = false,
    bool isFirstMessageRecord = false,
    bool isLastMessageRecord = false,
    bool hasId = false,
  }) {
    int value = 0;
    if (isFirstChunk) {
      if (tnf == null) throw ArgumentError('TNF must be provided for the first chunk.');
      value = _CF_MASK | tnf.value;
      if (isFirstMessageRecord) value |= _MB_MASK;
      if (hasId) value |= _IL_MASK;
    } else if (isLastChunk) {
      value = Tnf.unchanged.value;
      if (isLastMessageRecord) value |= _ME_MASK;
    } else { 
      value = _CF_MASK | Tnf.unchanged.value;
    }
    return NdefFlagByte._internal(value);
  }
}

class NdefTypeLengthField extends ApduField {
  static final zero = NdefTypeLengthField(0);
  static final forWkt = NdefTypeLengthField(1);

  NdefTypeLengthField(int length) : super(size: 1, name: "Type Length") {
    if (length < 0 || length > 255) throw ArgumentError('Type Length is invalid.');
    buffer[0] = length;
  }
}

class NdefPayloadLengthField extends ApduField {
  factory NdefPayloadLengthField(int length) {
    if (length < 256) {
      return NdefPayloadLengthField._short(length);
    } else {
      return NdefPayloadLengthField._long(length);
    }
  }

  NdefPayloadLengthField._short(int length) : super(size: 1, name: "Payload Length (SR)") {
    if (length < 0 || length > 255) throw ArgumentError('Payload Length for short record is invalid.');
    buffer[0] = length;
  }

  NdefPayloadLengthField._long(int length) : super(size: 4, name: "Payload Length") {
    if (length < 0 || length > 0xFFFFFFFF) throw ArgumentError('Payload Length for long record is invalid.');
    buffer[0] = (length >> 24) & 0xFF;
    buffer[1] = (length >> 16) & 0xFF;
    buffer[2] = (length >> 8) & 0xFF;
    buffer[3] = length & 0xFF;
  }
}

class NdefIdLengthField extends ApduField {
  NdefIdLengthField(int length) : super(size: 1, name: "ID Length") {
    if (length < 0 || length > 255) throw ArgumentError('ID Length is invalid.');
    buffer[0] = length;
  }
}

class NdefTypeField extends ApduData {
  final Tnf tnf;

  NdefTypeField._internal(Uint8List typeBytes, {required this.tnf}) 
      : super(typeBytes, name: "Type");

  factory NdefTypeField.wellKnown(String type) {
    return NdefTypeField._internal(ascii.encode(type), tnf: Tnf.wellKnown);
  }
  
  factory NdefTypeField.mediaType(String mimeType) {
    return NdefTypeField._internal(ascii.encode(mimeType), tnf: Tnf.mediaType);
  }

  factory NdefTypeField.externalType(String externalType) {
    return NdefTypeField._internal(ascii.encode(externalType), tnf: Tnf.externalType);
  }

  static final NdefTypeField text = NdefTypeField.wellKnown("T");
  static final NdefTypeField uri = NdefTypeField.wellKnown("U");
  static final NdefTypeField smartPoster = NdefTypeField.wellKnown("Sp");
  static final NdefTypeField textPlain = NdefTypeField.mediaType("text/plain");

  static final NdefTypeField empty = NdefTypeField._internal(Uint8List(0), tnf: Tnf.empty);
  static final NdefTypeField unknown = NdefTypeField._internal(Uint8List(0), tnf: Tnf.unknown);
  static final NdefTypeField unchanged = NdefTypeField._internal(Uint8List(0), tnf: Tnf.unchanged);
}

class NdefIdField extends ApduData {
  NdefIdField(Uint8List id) : super(id, name: "ID");
  
  factory NdefIdField.fromAscii(String id) {
    return NdefIdField(ascii.encode(id));
  }
}

class NdefPayload extends ApduData {
  NdefPayload(Uint8List payload) : super(payload, name: "Payload");
}