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
  String toString() =>
      buffer.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
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
  ApduData(Uint8List data, {required String name}) : super(size: data.length, name: name) {
    buffer.setAll(0, data);
  }
}