# Estructura de App Layer en Kotlin

Este documento describe la traducción completa de la librería `app_layer` de Dart a Kotlin para el proyecto Flutter HCE.

## Estructura de Archivos Creados

### Archivos Base (app_layer/)

- **Field.kt**: Clases base `ApduField`, `ApduSerializer` y `ApduData` - equivalentes a las clases base de Dart
- **Errors.kt**: Excepciones y códigos de error - traducción directa de `errors.dart`
- **StateMachine.kt**: Máquina de estados principal - traducción de `state_machine.dart`
- **Validation.kt**: Utilidades de validación adicionales

### Acceso a Archivos (file_access/)

#### Campos (fields/)

- **CommandFields.kt**: Campos de comandos APDU (`ApduClass`, `ApduInstruction`, `ApduParams`, `ApduLc`, `ApduLe`)
- **ResponseFields.kt**: Campos de respuesta APDU (`ApduStatusWord`)
- **TlvBlockFields.kt**: Campos para bloques TLV (`TlvTag`, `TlvLength`, `FileIdField`, etc.)
- **CapabilityContainerFields.kt**: Campos del contenedor de capacidades (`CcLenField`, `CcMappingVersionField`, etc.)

#### Serializadores (serializers/)

- **ApduCommandSerializer.kt**: Serializadores para comandos APDU (`ApduCommand`, `SelectCommand`, `ReadBinaryCommand`, `UpdateBinaryCommand`)
- **ApduResponseSerializer.kt**: Serializador para respuestas APDU (`ApduResponse`)
- **TlvBlockSerializer.kt**: Serializador para bloques TLV (`FileControlTlv`)
- **CapabilityContainerSerializer.kt**: Serializador para contenedor de capacidades (`CapabilityContainer`)

### Formato NDEF (ndef_format/)

#### Campos (fields/)

- **NdefRecordFields.kt**: Campos para registros NDEF (`NdefFlagByte`, `NdefTypeField`, `NdefPayload`, etc.)

#### Serializadores (serializers/)

- **NdefRecordSerializer.kt**: Serializador para registros NDEF individuales
- **NdefMessageSerializer.kt**: Serializador para mensajes NDEF completos con soporte para parsing y chunking

## Características Principales

### 1. **Compatibilidad Completa**

- Todas las funcionalidades de Dart han sido traducidas a Kotlin
- Mantiene la misma estructura de clases y métodos
- Comportamiento idéntico en serialización/deserialización

### 2. **Optimizaciones para Kotlin**

- Uso de `typealias Bytes = ByteArray` para mejor legibilidad
- Aprovechamiento de las características de Kotlin (data classes, companion objects, etc.)
- Manejo de excepciones específico de Kotlin

### 3. **Funcionalidades Incluidas**

- ✅ Máquina de estados HCE completa
- ✅ Parsing y serialización de comandos APDU
- ✅ Manejo de archivos CC y NDEF
- ✅ Soporte para chunking de registros NDEF
- ✅ Validación completa de formatos
- ✅ Manejo de errores robusto

### 4. **Máquina de Estados**

- Estados: IDLE → APP_SELECTED → CC_SELECTED/NDEF_SELECTED
- Soporte para comandos SELECT, READ_BINARY, UPDATE_BINARY
- Validación de AID estándar para aplicaciones NDEF
- Manejo de archivos CC (0xE103) y NDEF (0xE104)

### 5. **Serialización NDEF**

- Parser robusto para mensajes NDEF
- Soporte para records chunked
- Validación de estructura TNF
- Soporte para múltiples tipos de records (WKT, Media Type, External, etc.)

## Uso en Android

Los archivos están ubicados en el package correcto para ser utilizados por el plugin de Flutter HCE:

```
com.viridian.flutter_hce.app_layer.*
```

### Ejemplo de Uso

```kotlin
// Crear un mensaje NDEF
val records = listOf(
    NdefRecordTuple(
        type = NdefTypeField.text,
        payload = NdefPayload("Hello World".toByteArray()),
        id = NdefIdField.fromAscii("text1")
    )
)
val message = NdefMessageSerializer.fromRecords(records)

// Inicializar la máquina de estados
val stateMachine = HceStateMachine(message, isWritable = false)

// Procesar comandos APDU
val response = stateMachine.processCommand(rawApduCommand)
```

## Ventajas de la Implementación

1. **Total Compatibilidad**: Funciona idénticamente al código Dart
2. **Performance**: Optimizado para Android nativo
3. **Mantenibilidad**: Estructura clara y bien documentada
4. **Extensibilidad**: Fácil de extender con nuevas funcionalidades
5. **Robustez**: Manejo completo de errores y validaciones

Esta implementación proporciona una base sólida para el manejo de HCE (Host Card Emulation) en Android, completamente compatible con la implementación de Flutter/Dart.
