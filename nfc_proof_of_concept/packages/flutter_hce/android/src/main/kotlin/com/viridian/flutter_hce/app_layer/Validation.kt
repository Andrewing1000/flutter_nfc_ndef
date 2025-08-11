package com.viridian.flutter_hce.app_layer

/**
 * Utility class for common validation functions used across the HCE library
 */
object Validation {
    
    /**
     * Validates that a byte array represents a valid AID (Application Identifier)
     */
    fun validateAid(aid: Bytes): Boolean {
        return aid.isNotEmpty() && aid.size >= 5 && aid.size <= 16
    }
    
    /**
     * Validates that a file ID is within valid range (2 bytes)
     */
    fun validateFileId(fileId: Int): Boolean {
        return fileId in 0..0xFFFF
    }
    
    /**
     * Validates that an offset is within valid range for APDU operations
     */
    fun validateOffset(offset: Int, fileSize: Int): Boolean {
        return offset >= 0 && offset < fileSize
    }
    
    /**
     * Validates that a length is within valid range for APDU operations
     */
    fun validateLength(length: Int): Boolean {
        return length >= 0 && length <= 256
    }
    
    /**
     * Validates NDEF record structure
     */
    fun validateNdefRecord(type: Bytes, payload: Bytes?, id: Bytes?): Boolean {
        // Basic validation - can be extended based on TNF and specific requirements
        return type.isNotEmpty() || (payload?.isEmpty() == true && id == null)
    }
    
    /**
     * Checks if two byte arrays are equal
     */
    fun byteArraysEqual(a: Bytes, b: Bytes): Boolean {
        if (a.size != b.size) return false
        return a.contentEquals(b)
    }
}
