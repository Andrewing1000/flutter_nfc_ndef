# 🚀 NFC Intent Launching - Guía Completa

Esta guía te muestra cómo configurar tu aplicación Flutter HCE para que se abra automáticamente en una **pantalla específica** cuando se reciba un comando NFC con un AID registrado.

## ¿Qué es NFC Intent Launching?

El **NFC Intent Launching** permite que tu aplicación:

1. **Se abra automáticamente** cuando otro dispositivo NFC envía un comando a tu AID
2. **Navegue directamente** a una pantalla específica
3. **Reciba los datos NFC** que activaron la aplicación
4. **Procese automáticamente** la información recibida

## 📱 Configuración Android

### 1. AndroidManifest.xml

Copia la configuración de `android_manifest_nfc_example.xml` a tu `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Agregar dentro de <activity android:name=".MainActivity"> -->

<!-- INTENT FILTER PARA NFC TECH DISCOVERY -->
<intent-filter>
    <action android:name="android.nfc.action.TECH_DISCOVERED" />
    <category android:name="android.intent.category.DEFAULT" />
</intent-filter>

<!-- INTENT FILTER PARA NDEF DISCOVERY -->
<intent-filter>
    <action android:name="android.nfc.action.NDEF_DISCOVERED" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="*/*" />
</intent-filter>

<!-- TECNOLOGÍAS NFC SOPORTADAS -->
<meta-data
    android:name="android.nfc.action.TECH_DISCOVERED"
    android:resource="@xml/nfc_tech_filter" />
```

### 2. Archivos de Recursos XML

Crea los siguientes archivos en `android/app/src/main/res/xml/`:

#### `nfc_tech_filter.xml`

```xml
<resources>
    <tech-list>
        <tech>android.nfc.tech.IsoDep</tech>
    </tech-list>
</resources>
```

#### `apdu_service.xml`

```xml
<host-apdu-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/hce_service_name"
    android:requireDeviceUnlock="false">

    <aid-group android:description="@string/aid_group_name" android:category="other">
        <aid-filter android:name="D2760000850101"/>
        <aid-filter android:name="F0010203040506"/>
    </aid-group>
</host-apdu-service>
```

### 3. Strings de Recursos

Agrega a `android/app/src/main/res/values/strings.xml`:

```xml
<string name="hce_service_name">Flutter HCE Service</string>
<string name="aid_group_name">Flutter NDEF AIDs</string>
```

## 🎯 Configuración Flutter

### 1. Configurar NavigatorKey Global

```dart
// main.dart - Al inicio del archivo
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ← IMPORTANTE
      home: MyHomePage(),
    );
  }
}
```

### 2. Escuchar Eventos de Intent NFC

```dart
class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    _listenForNfcIntents(); // ← Agregar esto
  }

  // Escuchar eventos de Intent NFC
  void _listenForNfcIntents() {
    FlutterHce.nfcIntentEvents.listen(
      (intentData) {
        print('🚀 NFC Intent received: $intentData');
        _navigateToNfcScreen(intentData);
      },
      onError: (error) {
        print('❌ NFC Intent Error: $error');
      },
    );
  }

  // Navegar a pantalla específica
  void _navigateToNfcScreen(Map<String, dynamic> intentData) {
    if (navigatorKey.currentContext != null) {
      Navigator.of(navigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (context) => NfcActionScreen(intentData: intentData),
        ),
      );
    }
  }
}
```

### 3. Crear Pantalla Específica para NFC

```dart
class NfcActionScreen extends StatelessWidget {
  final Map<String, dynamic> intentData;

  const NfcActionScreen({Key? key, required this.intentData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC Intent Detected'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🚀 App Launched by NFC!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 16),
            Text('Intent Details:', style: TextStyle(fontSize: 18)),
            ...intentData.entries.map((entry) =>
              Text('${entry.key}: ${entry.value}')
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 🔄 Flujo de Funcionamiento

1. **Dispositivo NFC Externo** → Envía comando APDU con AID registrado (ej: `D2760000850101`)
2. **Android System** → Detecta el AID y lanza tu aplicación
3. **Flutter Plugin** → Recibe el Intent y extrae los datos NFC
4. **EventChannel** → Envía evento a `FlutterHce.nfcIntentEvents`
5. **Tu App Flutter** → Recibe el evento y navega automáticamente a `NfcActionScreen`
6. **Pantalla Específica** → Se muestra con los datos del Intent NFC

## 📝 Ejemplos de Uso

### Caso 1: Navegación Condicional

```dart
void _navigateToNfcScreen(Map<String, dynamic> intentData) {
  final String? action = intentData['action'];

  if (action == 'android.nfc.action.NDEF_DISCOVERED') {
    // Navegar a pantalla de lectura NDEF
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => NdefReaderScreen(data: intentData),
    ));
  } else if (action == 'android.nfc.action.TECH_DISCOVERED') {
    // Navegar a pantalla de tecnología específica
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => TechScreen(data: intentData),
    ));
  }
}
```

### Caso 2: Procesamiento Automático

```dart
void _navigateToNfcScreen(Map<String, dynamic> intentData) {
  // Extraer información específica
  final nfcData = intentData['data'] as Map<String, dynamic>?;
  final tagId = nfcData?['tag_id'] as List<int>?;

  if (tagId != null) {
    // Procesar automáticamente según el ID del tag
    _processTagId(tagId);

    // Navegar a resultado
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => ProcessResultScreen(tagId: tagId),
    ));
  }
}
```

### Caso 3: Diferentes Pantallas por AID

```dart
void _navigateToNfcScreen(Map<String, dynamic> intentData) {
  final nfcData = intentData['data'] as Map<String, dynamic>?;
  final aid = nfcData?['aid'] as String?;

  switch (aid) {
    case 'D2760000850101': // NDEF estándar
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => NdefScreen(data: intentData),
      ));
      break;
    case 'F0010203040506': // AID personalizado
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => CustomActionScreen(data: intentData),
      ));
      break;
    default:
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => GenericNfcScreen(data: intentData),
      ));
  }
}
```

## 🧪 Pruebas

### Prueba con otro dispositivo Android:

1. **Instala una app NFC** como "NFC Tools" o "TagWriter"
2. **Configura un tag virtual** con AID `D2760000850101`
3. **Acerca los dispositivos** - tu app debería abrirse automáticamente
4. **Verifica la navegación** - debería mostrar la pantalla específica

### Logs para Debugging:

```dart
FlutterHce.nfcIntentEvents.listen((intentData) {
  print('🚀 Intent Action: ${intentData['action']}');
  print('🚀 Intent Data: ${intentData['data']}');
  print('🚀 Intent Type: ${intentData['type']}');
});
```

## ⚠️ Notas Importantes

1. **launchMode**: Usa `singleTop` en AndroidManifest para evitar múltiples instancias
2. **Permisos**: Asegúrate de tener `android.permission.NFC`
3. **Hardware**: Solo funciona en dispositivos con NFC habilitado
4. **Timing**: El Intent llega antes de que Flutter esté completamente inicializado
5. **Background**: Si la app está cerrada, se abrirá automáticamente

## 🎉 ¡Listo!

Con esta configuración, tu aplicación Flutter HCE se abrirá automáticamente en una pantalla específica cada vez que reciba un comando NFC con uno de los AIDs registrados.

El usuario verá:

1. **Su dispositivo NFC se acerca** al tuyo
2. **Tu app se abre automáticamente** (incluso si estaba cerrada)
3. **Navega directamente** a la pantalla configurada
4. **Muestra la información** del comando NFC recibido
