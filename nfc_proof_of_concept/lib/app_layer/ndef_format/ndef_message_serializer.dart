import '../field.dart';
import './ndef_record_serializer.dart';
import './ndef_record_fields.dart';


typedef NdefRecordTuple = ({
  NdefTypeField type,
  NdefPayload? payload,
  NdefIdField? id,
});


class NdefMessageSerializer extends ApduSerializer {
  final List<NdefRecordSerializer> records;

  factory NdefMessageSerializer.fromRecords({
    required List<NdefRecordTuple> recordData,
  }) {
    if (recordData.isEmpty) {
      throw ArgumentError('Cannot create an NDEF message with zero records.');
    }

    final List<NdefRecordSerializer> serializedRecords = [];
    for (int i = 0; i < recordData.length; i++) {
      final data = recordData[i];
      serializedRecords.add(
        NdefRecordSerializer.record(
          type: data.type,
          payload: data.payload,
          id: data.id,
          isFirstInMessage: (i == 0),
          isLastInMessage: (i == recordData.length - 1),
        )
      );
    }
    return NdefMessageSerializer._internal(serializedRecords);
  }

  NdefMessageSerializer._internal(this.records) : super(name: "NDEF Message");

  @override
  void setFields() {
    fields = records;
  }
}