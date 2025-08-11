# Flutter HCE - Quick Setup

## Configuración Rápida para Proyectos Flutter

### 1. Agregar Dependencia

```yaml
dependencies:
  flutter_hce: ^1.0.0
```

### 2. Permisos Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc.hce" android:required="true" />
```

### 3. Servicio HCE (AndroidManifest.xml)

```xml
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
```

### 4. Configuración AID (res/xml/hce_aid_list.xml)

```xml
<?xml version="1.0" encoding="utf-8"?>
<host-apdu-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/hce_service_description"
    android:requireDeviceUnlock="false">
    <aid-group android:category="other"
        android:description="@string/hce_aid_group_description">
        <aid-filter android:name="D2760000850101" />
    </aid-group>
</host-apdu-service>
```

### 5. Strings (res/values/strings.xml)

```xml
<string name="hce_service_description">Flutter HCE Service</string>
<string name="hce_aid_group_description">NDEF AIDs</string>
```

### 6. Código Flutter

```dart
import 'package:flutter_hce/flutter_hce.dart';

// Inicializar HCE
final aid = FlutterHce.createStandardNdefAid();
final records = [
  FlutterHce.createTextRecord('Hello World!'),
  FlutterHce.createUriRecord('https://flutter.dev'),
];

await FlutterHce.init(aid: aid, records: records);

// Escuchar eventos
FlutterHce.transactionEvents.listen((event) {
  print('NFC transaction detected!');
});
```

Ver [SETUP_GUIDE.md](SETUP_GUIDE.md) para documentación completa.
