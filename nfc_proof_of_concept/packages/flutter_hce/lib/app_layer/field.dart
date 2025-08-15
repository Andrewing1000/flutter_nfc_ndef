import 'dart:typed_data';

abstract class ApduField {
  Uint8List _buffer;
  final String name;
  int _size;

  ApduField({required int size, required this.name})
      : _size = size,
        _buffer = Uint8List(size);

  int get length => _size;
  Uint8List get buffer => _buffer;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ApduField || runtimeType != other.runtimeType) return false;
    return _buffersEqual(_buffer, other._buffer);
  }

  @override
  int get hashCode {
    return _bufferHashCode(_buffer);
  }

  bool _buffersEqual(Uint8List buffer1, Uint8List buffer2) {
    if (buffer1.length != buffer2.length) return false;

    for (int i = 0; i < buffer1.length; i++) {
      if (buffer1[i] != buffer2[i]) return false;
    }

    return true;
  }

  int _bufferHashCode(Uint8List buffer) {
    int hash = 0;
    for (int i = 0; i < buffer.length; i++) {
      hash = hash * 31 + buffer[i];
      hash = hash & 0xFFFFFFFF;
    }
    return hash;
  }

  @override
  String toString() => buffer
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join(' ')
      .toUpperCase();
}

abstract class ApduSerializer extends ApduField {
  List<ApduField?> fields = [];

  ApduSerializer({required super.name, super.size = 0}) {
    setFields();
    _serialize();
  }

  /// Populates the `fields` list with all potential fields for serialization.
  /// Null values will be ignored during serialization.
  void setFields();

  @override
  Uint8List get buffer {
    _serialize();
    return super.buffer;
  }

  @override
  int get length { 
    var res = 0;
    for(final field in fields){
      res += field?.length ?? 0;
    }
    return res;
  }

  void _serialize() {
    var builder = BytesBuilder(copy: false);
    for (final field in fields) {
      if (field != null) {
        builder.add(field.buffer);
      }
    }
    _buffer = builder.takeBytes();
    _size = _buffer.length;
  }

  @override
  String toString() {
    return fields.map((field) {
      if (field != null) {
        return ' | ${field.name}: ${field.toString()}';
      } else {
        return '';
      }
    }).join();
  }
}

class ApduData extends ApduField {
  ApduData(Uint8List data, {required String name})
      : super(size: data.length, name: name) {
    buffer.setAll(0, data);
  }
}
