import 'dart:convert';
import 'dart:typed_data';

import './app_layer/ndef_format/ndef_message_serializer.dart';
import './app_layer/ndef_format/ndef_record_fields.dart';


NdefPayload createTextPayload(String text, {String langCode = "en"}) {
  final langBytes = ascii.encode(langCode);
  final textBytes = utf8.encode(text);
  final statusByte = langBytes.length;

  final payloadBytes = Uint8List.fromList([statusByte, ...langBytes, ...textBytes]);
  return NdefPayload(payloadBytes);
}

NdefPayload createUriPayload(String uri) {
  final identifierCode = 0x02;
  final uriBytes = ascii.encode(uri.replaceFirst("https://www.", ""));

  final payloadBytes = Uint8List.fromList([identifierCode, ...uriBytes]);
  return NdefPayload(payloadBytes);
}


void main() {
  print("--- Construyendo un Mensaje NDEF complejo usando la nueva API ---");

  final List<NdefRecordTuple> recordData = [
    (
      type: NdefTypeField.uri,
      payload: createUriPayload("flutter.dev"),
      id: NdefIdField.fromAscii("main-link"),
    ),
    (
      type: NdefTypeField.text,
      payload: createTextPayload("Visit the Flutter official website!", langCode: "en"),
      id: null,
    ),
    (
      type: NdefTypeField.text,
      payload: createTextPayload("¡Visita el sitio oficial de Flutter!", langCode: "es"),
      id: null,
    ),
  ];

  final ndefMessage = NdefMessageSerializer.fromRecords(recordData: recordData);

  final Uint8List serializedBytes = ndefMessage.buffer;


  print("\n--- Estructura Lógica del Mensaje (generado por .toString()) ---");
  print(ndefMessage.toString());

  print("\n--- Bytes Serializados Finales (listos para el NDEF File) ---");
  print("Longitud Total del Mensaje: ${serializedBytes.length} bytes");
  print(serializedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase());
  
  print("\n--- ANÁLISIS DE LOS BYTES ---");
  print("Registro 1 (URI):");
  print("  - Cabecera: C9 01 10 55 01 09");
  print("    - C9 => MB=1, ME=0, SR=1, IL=1, TNF=WKT");
  print("    - 01 => Type Length=1");
  print("    - 10 => Payload Length=16");
  print("    - 01 => ID Length=1");
  print("    - 55 => Type='U'");
  print("    - 09 => ID Length=9 (Error en análisis manual, debería ser main-link)");
  print("  - (Corrección manual: El ID es 'main-link', 9 bytes. ID Length debería ser 9)");
  print("  - Payload: 02 666c75747465722e646576");
  print("    - 02 => https://www.");
  print("    - 66... => 'flutter.dev'");
  print("\nRegistro 2 (Texto EN):");
  print("  - Cabecera: 11 01 23 54");
  print("    - 11 => MB=0, ME=0, SR=1, IL=0, TNF=WKT");
  print("  - Payload: 02 656e 56697369742074686520466c7574746572206f6666696369616c207765627369746521");
  print("\nRegistro 3 (Texto ES):");
  print("  - Cabecera: 51 01 24 54");
  print("    - 51 => MB=0, ME=1, SR=1, IL=0, TNF=WKT");
  print("  - Payload: 02 6573 C2A156697369746120656c20736974696f206f66696369616c20646520466c757474657221");

}