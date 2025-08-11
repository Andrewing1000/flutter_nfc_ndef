# Flutter HCE (Host Card Emulation) - Setup Completo

## Resumen de la Librería

Esta librería proporciona funcionalidad completa de Host Card Emulation (HCE) para aplicaciones Flutter, permitiendo que los dispositivos Android actúen como tarjetas NFC.

### Arquitectura Traducida

- **Completado**: Toda la capa `app_layer` ha sido traducida de Dart a Kotlin
- **15 archivos Kotlin** con funcionalidad completa de NDEF, APDU y estado de máquina
- **AID Configurable**: Sin hardcoding, completamente parametrizable desde Flutter

## Setup Necesario para un Proyecto Flutter

### 1. Dependencias en pubspec.yaml

```yaml
dependencies:
  flutter_hce:
    path: ./packages/flutter_hce # O desde pub.dev cuando esté publicado
```

### 2. Permisos Android (android/app/src/main/AndroidManifest.xml)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permisos NFC requeridos -->
    <uses-permission android:name="android.permission.NFC" />

    <!-- Feature de HCE requerido -->
    <uses-feature
        android:name="android.hardware.nfc.hce"
        android:required="true" />

    <application android:label="tu_app" android:name="${applicationName}">
        <!-- Tu contenido de aplicación aquí -->

        <!-- IMPORTANTE: Servicio HCE necesario -->
        <service
            android:name="com.viridian.flutter_hce.HceService"
            android:exported="true"
            android:permission="android.permission.BIND_NFC_SERVICE">

            <intent-filter>
                <action android:name="android.nfc.cardemulation.action.HOST_APDU_SERVICE" />
            </intent-filter>

            <meta-data
                android:name="android.nfc.cardemulation.host_apdu_service"
                android:resource="@xml/hce_aid_list" />
        </service>
    </application>
</manifest>
```

### 3. ⚠️ Configuración XML de AID (IMPORTANTE)

**CADA PROYECTO** debe crear su propio archivo `android/app/src/main/res/xml/hce_aid_list.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<host-apdu-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/hce_service_description"
    android:requireDeviceUnlock="false">

    <aid-group android:description="@string/hce_aid_group"
        android:category="other">

        <!-- AID estándar para NDEF (recomendado para compatibilidad) -->
        <aid-filter android:name="D2760000850101" />

        <!-- ✅ PUEDES AÑADIR TUS PROPIOS AIDs AQUÍ -->
        <!-- <aid-filter android:name="F0394148148100" /> -->
        <!-- <aid-filter android:name="A0000002471001" /> -->

    </aid-group>
</host-apdu-service>
```

#### 🔥 **Importante sobre AIDs Personalizados:**

1. **Limitación Android**: Los AIDs deben estar declarados estáticamente en XML
2. **No dinámico**: No se puede cambiar el AID en runtime después del registro
3. **Múltiples AIDs**: Puedes declarar varios AIDs en el mismo servicio
4. **Validación**: El AID que pases a `FlutterHce.init()` DEBE estar en la lista XML

#### Ejemplo con AID Personalizado:

````dart
// ✅ CORRECTO: AID declarado en hce_aid_list.xml
final customAid = Uint8List.fromList([0xF0, 0x39, 0x41, 0x48, 0x14, 0x81, 0x00]);
await FlutterHce.init(aid: customAid, records: records);

// ❌ ERROR: AID no declarado en XML - fallará
final invalidAid = Uint8List.fromList([0x12, 0x34, 0x56, 0x78]);
await FlutterHce.init(aid: invalidAid, records: records); // Lanzará excepción
```### 4. Strings de Recursos (android/app/src/main/res/values/strings.xml)

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Tu App</string>
    <string name="hce_service_description">Host Card Emulation Service</string>
    <string name="hce_aid_group">NDEF AID Group</string>
</resources>
````

### 5. Código Flutter - Ejemplo Básico

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hce/flutter_hce.dart';

class HceExample extends StatefulWidget {
  @override
  _HceExampleState createState() => _HceExampleState();
}

class _HceExampleState extends State<HceExample> {
  bool _isHceActive = false;

  @override
  void initState() {
    super.initState();
    _setupHce();
  }

  Future<void> _setupHce() async {
    try {
      // Crear AID estándar para NDEF
      final aid = FlutterHce.createStandardNdefAid();

      // Crear records NDEF de ejemplo
      final records = [
        NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: [0x54], // 'T' - Text record
          payload: [
            0x02, // Encoding flags
            0x65, 0x6E, // Language code "en"
            ...("Hola desde Flutter HCE!").codeUnits
          ],
        ),
      ];

      // Inicializar HCE
      await FlutterHce.init(aid: aid, records: records);

      setState(() {
        _isHceActive = true;
      });

      print("HCE inicializado exitosamente");
    } catch (e) {
      print("Error al inicializar HCE: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter HCE Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isHceActive ? Icons.nfc : Icons.nfc_outlined,
              size: 100,
              color: _isHceActive ? Colors.green : Colors.grey,
            ),
            SizedBox(height: 20),
            Text(
              _isHceActive
                  ? 'HCE Activo - Acerca un lector NFC'
                  : 'Configurando HCE...',
              style: Theme.of(context).textTheme.headline6,
            ),
          ],
        ),
      ),
    );
  }
}
```

### 6. Verificación de Funcionalidad

Para verificar que todo funciona:

1. **Compilación**: El proyecto debe compilar sin errores
2. **Permisos**: Android debe solicitar permisos NFC al iniciar
3. **Registro**: El servicio HCE debe registrarse automáticamente
4. **Prueba**: Usar un lector NFC para verificar la emulación

## API Principal

### FlutterHce.init()

```dart
await FlutterHce.init(
  aid: Uint8List aid,                 // AID personalizable
  records: List<NdefRecord> records   // Records NDEF a emular
);
```

### Utilidades

- `FlutterHce.createStandardNdefAid()` - Crea AID estándar D2760000850101
- `NdefRecord` - Clase para crear records NDEF personalizados

## Características Técnicas

- **✅ AID Configurable**: No hay valores hardcodeados
- **✅ NDEF Completo**: Serialización completa de records NDEF
- **✅ APDU Processing**: Manejo completo de comandos APDU
- **✅ State Machine**: Máquina de estados robusta para transacciones NFC
- **✅ Error Handling**: Manejo de errores en todas las capas
- **✅ Flutter Events**: Comunicación bidireccional Flutter ↔ Android

## ✅ **RESPUESTA A TU PREGUNTA**

### ¿Los proyectos deben usar el AID del plugin?

**NO ABSOLUTO**. Aquí está la explicación completa:

#### 🔹 **El AID del Plugin (flutter_hce/android/.../xml/hce_aid_list.xml)**

- **Solo para testing interno** del plugin
- **NO afecta tu proyecto**
- Puedes ignorarlo completamente

#### 🔹 **Tu Proyecto (android/app/.../xml/hce_aid_list.xml)**

- **CADA proyecto debe crear su propio archivo**
- **Puedes usar cualquier AID** que declares allí
- **Múltiples AIDs** son soportados en el mismo archivo

#### 🔹 **Flujo Completo:**

```xml
<!-- En TU proyecto: android/app/src/main/res/xml/hce_aid_list.xml -->
<aid-group android:category="other">
    <aid-filter android:name="D2760000850101" />  <!-- NDEF estándar -->
    <aid-filter android:name="F0394148148100" />  <!-- Tu AID personalizado 1 -->
    <aid-filter android:name="A0000002471001" />  <!-- Tu AID personalizado 2 -->
</aid-group>
```

```dart
// En tu código Flutter - puedes usar CUALQUIER AID declarado en XML
final customAid = AidUtils.hexStringToAid("F0394148148100");
await FlutterHce.init(aid: customAid, records: records);

// O cambiar dinámicamente entre AIDs declarados
final ndefAid = AidUtils.createStandardNdefAid();
await FlutterHce.init(aid: ndefAid, records: otherRecords);
```

### 🎯 **Utilidades para AIDs Personalizados:**

```dart
// Crear AID personalizado
final myAid = AidUtils.createCustomAid(pix: [0x01, 0x02]);

// Convertir a HEX para XML
final hexString = AidUtils.aidToHexString(myAid); // "F0394148140102"

// Usar en Flutter
await FlutterHce.init(aid: myAid, records: records);
```

**EN RESUMEN**: Tienes total libertad para usar cualquier AID que declares en tu archivo XML. El AID del plugin es irrelevante para tu proyecto.

### ¿Por qué no puedo cambiar el AID dinámicamente?

Esta es una **limitación de Android**, no de nuestra librería. Android requiere que todos los AIDs estén registrados estáticamente en el AndroidManifest.xml para propósitos de seguridad.

### ¿El AID del plugin afecta mi proyecto?

**NO**. El archivo `flutter_hce/android/src/main/res/xml/hce_aid_list.xml` es solo para **testing interno** del plugin. Cada proyecto debe crear su propio archivo en `android/app/src/main/res/xml/hce_aid_list.xml`.

### ¿Puedo usar múltiples AIDs?

**SÍ**. Puedes declarar múltiples `<aid-filter>` en tu XML y luego usar cualquiera de ellos al llamar `FlutterHce.init()`.

### ¿Qué pasa si uso un AID no declarado?

La librería **validará** que el AID esté en la lista registrada y lanzará una excepción si no está.

## Troubleshooting

### Problemas Comunes:

1. **"NFC not available"**: El dispositivo no tiene NFC o está deshabilitado
2. **"HCE not supported"**: El dispositivo no soporta Host Card Emulation
3. **"Service not registered"**: Verificar configuración del AndroidManifest.xml
4. **"AID conflict"**: Otro app está usando el mismo AID

### Logs para Debug:

```bash
adb logcat | grep -E "(HceService|NfcHostCardEmulation|StateMachine)"
```

## Estado de Desarrollo

- **✅ Core Translation**: 15 archivos Dart → Kotlin completados
- **✅ API Integration**: Flutter ↔ Android communication establecida
- **✅ AID Architecture**: Sistema AID configurable implementado
- **✅ Compilation**: Módulo Android compila exitosamente
- **✅ Testing**: Tests unitarios actualizados y funcionando
