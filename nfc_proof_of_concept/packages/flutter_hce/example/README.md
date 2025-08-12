# Flutter HCE Example - Refactored Architecture

Este ejemplo demuestra el uso de la librería Flutter HCE con una arquitectura refactorizada que separa la lógica de negocio de la interfaz de usuario.

## Arquitectura

### Separación de Responsabilidades

La aplicación está organizada en tres capas principales:

1. **Lógica de Negocio** (`hce_service.dart`)

   - Maneja toda la lógica HCE
   - Proporciona streams para el estado de la aplicación
   - Encapsula las llamadas a la API de Flutter HCE

2. **Widgets de UI** (`hce_widgets.dart`)

   - Componentes de interfaz reutilizables
   - Escucha los streams del servicio
   - Maneja la interacción del usuario

3. **Aplicación Principal** (`main.dart`)
   - Ensambla los componentes
   - Configuración básica de la aplicación

### Componentes

#### HceService

- **Singleton**: Gestiona el estado global de HCE
- **Streams**: Emite cambios de estado para que la UI pueda reaccionar
- **Factory Methods**: Usa los nuevos factory methods para crear registros NDEF de forma inteligente

#### Widgets Especializados

- **HceStatusWidget**: Muestra el estado de NFC y HCE
- **HceControlsWidget**: Botones de control para diferentes tipos de tarjetas HCE
- **HceLogsWidget**: Display de logs de transacciones en tiempo real

## Nuevos Factory Methods

La librería `app_layer` ahora incluye factory methods inteligentes para crear registros NDEF:

### `NdefRecordSerializer.text(String text, String language)`

Crea un registro de texto WKT con formato automático del payload.

```dart
final textRecord = NdefRecordSerializer.text('Hello World', 'en');
```

### `NdefRecordSerializer.uri(String uri)`

Crea un registro URI WKT con compresión automática de esquemas comunes.

```dart
final uriRecord = NdefRecordSerializer.uri('https://flutter.dev');
```

### `NdefRecordSerializer.json(Map<String, dynamic> jsonData)`

Crea un registro JSON usando el MIME type `text/json`.

```dart
final jsonRecord = NdefRecordSerializer.json({
  'name': 'Flutter HCE',
  'version': '1.0.0'
});
```

## Ventajas de la Nueva Arquitectura

1. **Mejor Testabilidad**: La lógica de negocio está separada de la UI
2. **Reutilización**: Los widgets pueden usarse en otras aplicaciones
3. **Mantenibilidad**: Cambios en la lógica no afectan la UI y viceversa
4. **Streams Reactivos**: La UI se actualiza automáticamente con los cambios de estado
5. **Factory Methods Inteligentes**: Creación de registros NDEF más fácil y menos propensa a errores

## Uso de los Factory Methods

Los factory methods aprovechan mejor el fuerte tipado de la librería `app_layer`:

### Antes (Manual):

```dart
final textPayload = _createTextPayload('Hello', 'en');
final textRecord = NdefRecordSerializer.record(
  type: NdefTypeField.text,
  payload: NdefPayload(textPayload),
);
```

### Ahora (Factory Method):

```dart
final textRecord = NdefRecordSerializer.text('Hello', 'en');
```

## Características Avanzadas

### Deserialización Inteligente

El deserializador `fromBytes` ahora usa las instancias `static final` cuando es posible:

- `NdefTypeField.text` para registros de texto WKT
- `NdefTypeField.uri` para registros URI WKT
- `NdefTypeField.textJson` para registros JSON
- etc.

### Métodos de Conveniencia

Los registros deserializados incluyen métodos getter para extraer datos tipados:

```dart
final record = NdefRecordSerializer.fromBytes(rawData);

// Para registros de texto
final textContent = record.textContent;
final language = record.textLanguage;

// Para registros URI
final uri = record.uriContent;

// Para registros JSON
final jsonData = record.jsonContent;
```

## Ejecución

```bash
cd example
flutter pub get
flutter run
```

La aplicación permite probar diferentes tipos de tarjetas HCE:

- Tarjeta de Texto
- Tarjeta URI
- Tarjeta JSON
- Tarjeta Multi-Registro

Cada tarjeta demuestra el uso de los nuevos factory methods y la arquitectura reactiva.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
