# Flutter HCE - Host Card Emulation Setup Guide

Esta guía te explica cómo configurar tu proyecto Flutter para usar la funcionalidad de Host Card Emulation (HCE) con esta librería.

## Requisitos Previos

### Dispositivos Compatibles

- **Android 4.4+ (API 19+)**: HCE está disponible desde Android KitKat
- **Hardware NFC**: El dispositivo debe tener chip NFC
- **Soporte HCE**: El dispositivo debe soportar Host Card Emulation

### Verificar Compatibilidad

```dart
// Verificar estado NFC
final nfcState = await FlutterHce.checkNfcState();
print('NFC State: $nfcState'); // 'enabled', 'disabled', 'not_supported'
```

## Configuración del Proyecto

### 1. Agregar la Dependencia

En tu `pubspec.yaml`:

```yaml
dependencies:
  flutter_hce:
    path: ../path/to/flutter_hce # O desde pub.dev cuando esté publicado
```

### 2. Configuración Android

#### 2.1 Permisos en AndroidManifest.xml

Agrega estos permisos en `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Permisos requeridos para NFC -->
    <uses-permission android:name="android.permission.NFC" />

    <!-- Feature requerido para HCE -->
    <uses-feature
        android:name="android.hardware.nfc.hce"
        android:required="true" />

    <application>
        <!-- Tu configuración de aplicación existente -->

        <!-- Servicio HCE -->
        <service
            android:name="com.viridian.flutter_hce.HceService"
            android:exported="true"
            android:permission="android.permission.BIND_NFC_SERVICE">
            <intent-filter>
                <action android:name="android.nfc.cardemulation.action.HOST_APDU_SERVICE" />
            </intent-filter>

            <!-- Configuración de AIDs -->
            <meta-data
                android:name="android.nfc.cardemulation.host_apdu_service"
                android:resource="@xml/hce_aid_list" />
        </service>

    </application>
</manifest>
```

#### 2.2 Configuración de AIDs

Crea el archivo `android/app/src/main/res/xml/hce_aid_list.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<host-apdu-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/hce_service_description"
    android:requireDeviceUnlock="false">

    <aid-group
        android:category="other"
        android:description="@string/hce_aid_group_description">

        <!-- AID estándar NDEF -->
        <aid-filter android:name="D2760000850101" />

        <!-- Agrega tus AIDs personalizados aquí -->
        <!-- <aid-filter android:name="A000000476416E64726F6964" /> -->

    </aid-group>
</host-apdu-service>
```

#### 2.3 Strings Resources

Agrega en `android/app/src/main/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Tus strings existentes -->

    <!-- Strings para HCE -->
    <string name="hce_service_description">Servicio HCE para emulación NDEF</string>
    <string name="hce_aid_group_description">AIDs estándar NDEF para Host Card Emulation</string>
</resources>
```

### 3. Uso en Flutter

#### 3.1 Inicialización Básica

```dart
import 'package:flutter_hce/flutter_hce.dart';
import 'dart:typed_data';

class HceManager {
  static Future<void> initializeHce() async {
    try {
      // Crear AID estándar NDEF
      final aid = FlutterHce.createStandardNdefAid();

      // Crear registros NDEF
      final records = [
        FlutterHce.createTextRecord('¡Hola desde Flutter HCE!'),
        FlutterHce.createUriRecord('https://flutter.dev'),
      ];

      // Inicializar HCE
      final success = await FlutterHce.init(
        aid: aid,
        records: records,
        isWritable: false,          // Solo lectura por defecto
        maxNdefFileSize: 2048,      // 2KB máximo
      );

      if (success) {
        print('HCE inicializado correctamente!');
      } else {
        print('Error al inicializar HCE');
      }

    } catch (e) {
      print('Error HCE: $e');
    }
  }
}
```

#### 3.2 Escuchar Eventos de Transacción

```dart
class HceEventHandler {
  static StreamSubscription<HceTransactionEvent>? _subscription;

  static void startListening() {
    _subscription = FlutterHce.transactionEvents.listen(
      (event) {
        switch (event.type) {
          case HceEventType.transaction:
            print('Transacción NFC detectada');
            print('Comando: ${event.command?.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
            print('Respuesta: ${event.response?.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
            break;

          case HceEventType.deactivated:
            print('NFC desactivado, razón: ${event.reason}');
            break;
        }
      },
      onError: (error) {
        print('Error en eventos HCE: $error');
      },
    );
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}
```

#### 3.3 Ejemplo Completo en Widget

```dart
class HceWidget extends StatefulWidget {
  @override
  _HceWidgetState createState() => _HceWidgetState();
}

class _HceWidgetState extends State<HceWidget> {
  String _status = 'Inicializando...';
  String _nfcState = 'Desconocido';
  StreamSubscription<HceTransactionEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _initializeHce();
    _checkNfcState();
    _startListening();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeHce() async {
    try {
      final aid = FlutterHce.createStandardNdefAid();
      final records = [
        FlutterHce.createTextRecord('Mi aplicación Flutter'),
        FlutterHce.createUriRecord('https://miapp.com'),
      ];

      final success = await FlutterHce.init(
        aid: aid,
        records: records,
      );

      setState(() {
        _status = success ? 'HCE Activo' : 'Error en HCE';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _checkNfcState() async {
    final state = await FlutterHce.checkNfcState();
    setState(() {
      _nfcState = state;
    });
  }

  void _startListening() {
    _subscription = FlutterHce.transactionEvents.listen((event) {
      // Manejar eventos de transacción
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transacción NFC detectada!')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Flutter HCE')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estado HCE: $_status'),
            Text('Estado NFC: $_nfcState'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkNfcState,
              child: Text('Verificar NFC'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## AIDs Personalizados

### Crear AID Personalizado

```dart
// AID personalizado (5-16 bytes)
final customAid = FlutterHce.createCustomAid([
  0xA0, 0x00, 0x00, 0x04, 0x76, 0x41, 0x6E, 0x64, 0x72, 0x6F, 0x69, 0x64
]);

// Usar en inicialización
await FlutterHce.init(
  aid: customAid,
  records: records,
);
```

### Actualizar hce_aid_list.xml

```xml
<aid-group android:category="other">
    <!-- AID estándar NDEF -->
    <aid-filter android:name="D2760000850101" />

    <!-- Tu AID personalizado -->
    <aid-filter android:name="A000000476416E64726F6964" />
</aid-group>
```

## Tipos de Registros NDEF

### Registro de Texto

```dart
// Texto básico
final textRecord = FlutterHce.createTextRecord('Hola Mundo');

// Texto con idioma específico
final textRecord = FlutterHce.createTextRecord('Bonjour', language: 'fr');
```

### Registro URI

```dart
final uriRecord = FlutterHce.createUriRecord('https://flutter.dev');
```

### Registro Personalizado

```dart
final customRecord = FlutterHce.createRawRecord(
  type: 'application/json',
  payload: Uint8List.fromList('{"key": "value"}'.codeUnits),
  id: Uint8List.fromList([0x01, 0x02]), // Opcional
);
```

## Troubleshooting

### Problemas Comunes

1. **"HCE no está disponible"**

   - Verifica que el dispositivo tenga Android 4.4+
   - Asegúrate de que el NFC esté habilitado
   - Verifica que el dispositivo soporte HCE

2. **"Permisos denegados"**

   - Revisa que los permisos NFC estén en AndroidManifest.xml
   - Verifica la configuración del servicio HCE

3. **"AID ya en uso"**
   - Otro app puede estar usando el mismo AID
   - Usa un AID personalizado único

### Depuración

```dart
// Verificar estado del sistema
Future<void> debugHceState() async {
  final nfcState = await FlutterHce.checkNfcState();
  final isInitialized = await FlutterHce.isStateMachineInitialized();

  print('NFC State: $nfcState');
  print('HCE Initialized: $isInitialized');
}
```

## Limitaciones

- **Solo Android**: HCE no está disponible en iOS
- **Un AID por vez**: Solo se puede registrar un AID principal
- **Tamaño limitado**: Los registros NDEF tienen límites de tamaño
- **Categoría "other"**: Los AIDs personalizados deben usar categoría "other"

## Recursos Adicionales

- [Documentación oficial de HCE](https://developer.android.com/guide/topics/connectivity/nfc/hce)
- [Especificación NDEF](https://nfc-forum.org/our-work/specification-releases/specifications/nfc-forum-technical-specifications/)
- [Registros de AIDs](https://www.aidregistry.com/)
