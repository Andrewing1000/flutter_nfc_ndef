package com.viridian.flutter_hce.app_layer.file_access.serializers

import com.viridian.flutter_hce.app_layer.file_access.serializers.ApduCommand

fun main() {
    println("=== Verificación de Compatibilidad Kotlin-Flutter ===\n")
    
    testSelectCommand()
    testReadBinaryCommand()
    testUpdateBinaryCommand()
    testParsingCompatibility()
}

fun testSelectCommand() {
    println("1. Prueba SELECT Command:")
    
    // Test SELECT NDEF Application: 00 A4 00 0C 07 D2 76 00 00 85 01 01
    val ndefAppCommand = byteArrayOf(0x00, 0xA4.toByte(), 0x00, 0x0C, 0x07, 
                                    0xD2.toByte(), 0x76, 0x00, 0x00, 0x85.toByte(), 0x01, 0x01)
    val parsedNdef = ApduCommand.fromBytes(ndefAppCommand) as SelectCommand
    val reconstructedNdef = parsedNdef.toByteArray()
    
    println("   SELECT NDEF App: ${bytesToHex(reconstructedNdef)}")
    println("   Expected:       ${bytesToHex(ndefAppCommand)}")
    println("   ✓ Match: ${reconstructedNdef.contentEquals(ndefAppCommand)}\n")
    
    // Test SELECT CC File: 00 A4 00 0C 02 E1 03
    val ccCommand = byteArrayOf(0x00, 0xA4.toByte(), 0x00, 0x0C, 0x02, 0xE1.toByte(), 0x03)
    val parsedCC = ApduCommand.fromBytes(ccCommand) as SelectCommand
    val reconstructedCC = parsedCC.toByteArray()
    
    println("   SELECT CC File: ${bytesToHex(reconstructedCC)}")
    println("   Expected:       ${bytesToHex(ccCommand)}")
    println("   ✓ Match: ${reconstructedCC.contentEquals(ccCommand)}\n")
}

fun testReadBinaryCommand() {
    println("2. Prueba READ BINARY Command:")
    
    // Test READ BINARY offset 0, length 15: 00 B0 00 00 0F
    val readCommand = byteArrayOf(0x00, 0xB0.toByte(), 0x00, 0x00, 0x0F)
    val parsedRead = ApduCommand.fromBytes(readCommand) as ReadBinaryCommand
    val reconstructedRead = parsedRead.toByteArray()
    
    println("   READ BINARY(0,15): ${bytesToHex(reconstructedRead)}")
    println("   Expected:          ${bytesToHex(readCommand)}")
    println("   ✓ Match: ${reconstructedRead.contentEquals(readCommand)}")
    println("   ✓ Offset: ${parsedRead.offset}")
    println("   ✓ Length: ${parsedRead.lengthToRead}\n")
    
    // Test READ BINARY with offset 256: 00 B0 01 00 64
    val read256Command = byteArrayOf(0x00, 0xB0.toByte(), 0x01, 0x00, 0x64)
    val parsedRead256 = ApduCommand.fromBytes(read256Command) as ReadBinaryCommand
    val reconstructedRead256 = parsedRead256.toByteArray()
    
    println("   READ BINARY(256,100): ${bytesToHex(reconstructedRead256)}")
    println("   Expected:             ${bytesToHex(read256Command)}")
    println("   ✓ Match: ${reconstructedRead256.contentEquals(read256Command)}")
    println("   ✓ Offset: ${parsedRead256.offset}")
    println("   ✓ Length: ${parsedRead256.lengthToRead}\n")
}

fun testUpdateBinaryCommand() {
    println("3. Prueba UPDATE BINARY Command:")
    
    // Test UPDATE BINARY with "Hello": 00 D6 00 00 05 48 65 6C 6C 6F
    val updateCommand = byteArrayOf(0x00, 0xD6.toByte(), 0x00, 0x00, 0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F)
    val parsedUpdate = ApduCommand.fromBytes(updateCommand) as UpdateBinaryCommand
    val reconstructedUpdate = parsedUpdate.toByteArray()
    
    println("   UPDATE BINARY(0, \"Hello\"): ${bytesToHex(reconstructedUpdate)}")
    println("   Expected:                  ${bytesToHex(updateCommand)}")
    println("   ✓ Match: ${reconstructedUpdate.contentEquals(updateCommand)}")
    println("   ✓ Offset: ${parsedUpdate.offset}")
    println("   ✓ Data: ${bytesToHex(parsedUpdate.dataToWrite)}\n")
    
    // Test UPDATE BINARY with offset 100: 00 D6 00 64 03 FF 00 FF
    val update100Command = byteArrayOf(0x00, 0xD6.toByte(), 0x00, 0x64, 0x03, 0xFF.toByte(), 0x00, 0xFF.toByte())
    val parsedUpdate100 = ApduCommand.fromBytes(update100Command) as UpdateBinaryCommand
    val reconstructedUpdate100 = parsedUpdate100.toByteArray()
    
    println("   UPDATE BINARY(100, data): ${bytesToHex(reconstructedUpdate100)}")
    println("   Expected:                 ${bytesToHex(update100Command)}")
    println("   ✓ Match: ${reconstructedUpdate100.contentEquals(update100Command)}")
    println("   ✓ Offset: ${parsedUpdate100.offset}")
    println("   ✓ Data: ${bytesToHex(parsedUpdate100.dataToWrite)}\n")
}

fun testParsingCompatibility() {
    println("4. Prueba de Parsing (Round-trip):")
    
    // Test varios comandos y verificar que el parsing sea bidireccional
    val testCommands = listOf(
        byteArrayOf(0x00, 0xA4.toByte(), 0x00, 0x0C, 0x07, 0xD2.toByte(), 0x76, 0x00, 0x00, 0x85.toByte(), 0x01, 0x01),
        byteArrayOf(0x00, 0xB0.toByte(), 0x02, 0x00, 0xFF.toByte()),
        byteArrayOf(0x00, 0xD6.toByte(), 0x01, 0x00, 0x04, 0xDE.toByte(), 0xAD.toByte(), 0xBE.toByte(), 0xEF.toByte())
    )
    
    for ((index, originalBytes) in testCommands.withIndex()) {
        val parsedCommand = ApduCommand.fromBytes(originalBytes)
        val reconstructedBytes = parsedCommand.toByteArray()
        
        val commandType = when (parsedCommand) {
            is SelectCommand -> "SELECT"
            is ReadBinaryCommand -> "READ_BINARY"
            is UpdateBinaryCommand -> "UPDATE_BINARY"
            else -> "UNKNOWN"
        }
        
        println("   Test ${index + 1} ($commandType):")
        println("   Original:  ${bytesToHex(originalBytes)}")
        println("   Reconstructed: ${bytesToHex(reconstructedBytes)}")
        println("   ✓ Perfect match: ${originalBytes.contentEquals(reconstructedBytes)}\n")
    }
}

fun bytesToHex(bytes: ByteArray): String {
    return bytes.joinToString(" ") { "%02X".format(it) }
}
