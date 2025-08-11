import 'dart:typed_data';
import 'dart:math';

/// Utilidades para generar y validar AIDs para Host Card Emulation
class AidUtils {
  /// AID estándar para NDEF (recomendado para máxima compatibilidad)
  static const List<int> STANDARD_NDEF_AID = [
    0xD2,
    0x76,
    0x00,
    0x00,
    0x85,
    0x01,
    0x01
  ];

  /// Genera el AID estándar NDEF como Uint8List
  static Uint8List createStandardNdefAid() {
    return Uint8List.fromList(STANDARD_NDEF_AID);
  }

  /// Genera un AID personalizado válido
  ///
  /// Formato típico de AID:
  /// - RID (Registered ID): 5 bytes asignados por ISO
  /// - PIX (Proprietary Application Identifier Extension): 0-11 bytes
  ///
  /// Para aplicaciones propias, se recomienda usar un RID de prueba
  /// como 0xD0D1D2D3D4 seguido de tu identificador único.
  static Uint8List createCustomAid({
    List<int>? rid,
    List<int>? pix,
  }) {
    // RID por defecto para testing (NO usar en producción)
    rid ??= [0xF0, 0x39, 0x41, 0x48, 0x14];

    // PIX aleatorio si no se especifica
    if (pix == null) {
      final random = Random();
      pix = List.generate(2, (index) => random.nextInt(256));
    }

    final aid = [...rid, ...pix];

    // Validar longitud (5-16 bytes según ISO 7816-4)
    if (aid.length < 5 || aid.length > 16) {
      throw ArgumentError(
          'AID debe tener entre 5 y 16 bytes. Actual: ${aid.length}');
    }

    return Uint8List.fromList(aid);
  }

  /// Convierte un AID a string hexadecimal para usar en XML
  ///
  /// Ejemplo: [0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01] -> "D2760000850101"
  static String aidToHexString(Uint8List aid) {
    return aid
        .map((byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0'))
        .join('');
  }

  /// Convierte string hexadecimal a AID
  ///
  /// Ejemplo: "D2760000850101" -> [0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]
  static Uint8List hexStringToAid(String hexString) {
    if (hexString.length % 2 != 0) {
      throw ArgumentError('String hexadecimal debe tener longitud par');
    }

    final bytes = <int>[];
    for (int i = 0; i < hexString.length; i += 2) {
      final hex = hexString.substring(i, i + 2);
      bytes.add(int.parse(hex, radix: 16));
    }

    return Uint8List.fromList(bytes);
  }

  /// Valida que un AID sea válido según ISO 7816-4
  static bool isValidAid(Uint8List aid) {
    // Debe tener entre 5 y 16 bytes
    if (aid.length < 5 || aid.length > 16) {
      return false;
    }

    // No debe ser todo ceros
    if (aid.every((byte) => byte == 0)) {
      return false;
    }

    return true;
  }

  /// Genera documentación XML para un AID
  static String generateXmlDocumentation(Uint8List aid, String description) {
    final hexString = aidToHexString(aid);

    return '''
<!-- $description -->
<aid-filter android:name="$hexString" />''';
  }

  /// Ejemplos de AIDs comunes
  static Map<String, Uint8List> get commonAids => {
        'NDEF Standard': createStandardNdefAid(),
        'Custom Example 1': createCustomAid(pix: [0x01, 0x00]),
        'Custom Example 2': createCustomAid(pix: [0x02, 0x00]),
      };

  /// Imprime ejemplos de configuración XML
  static void printXmlExamples() {
    print('=== Ejemplos de configuración XML ===\n');

    commonAids.forEach((name, aid) {
      print('<!-- $name -->');
      print('<aid-filter android:name="${aidToHexString(aid)}" />');
      print('');
    });

    print('=== Para usar en Flutter ===\n');
    commonAids.forEach((name, aid) {
      print('// $name');
      print('final aid = AidUtils.hexStringToAid("${aidToHexString(aid)}");');
      print('await FlutterHce.init(aid: aid, records: records);');
      print('');
    });
  }
}
