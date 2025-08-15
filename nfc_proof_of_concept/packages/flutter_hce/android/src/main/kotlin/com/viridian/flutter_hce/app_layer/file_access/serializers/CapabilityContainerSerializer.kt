package com.viridian.flutter_hce.app_layer.file_access.serializers

import com.viridian.flutter_hce.app_layer.ApduSerializer
import com.viridian.flutter_hce.app_layer.file_access.fields.*

class CapabilityContainer(
    private val fileDescriptors: List<FileControlTlv>,
    maxResponseSize: Int? = null,
    maxCommandSize: Int? = null
) : ApduSerializer("Capability Container") {
    
    private val cclen: CcLenField
    private val version: CcMappingVersionField = CcMappingVersionField.v2_0
    private val mLe: CcMaxApduDataSizeField = CcMaxApduDataSizeField.mLe(maxResponseSize ?: 0x00FF)
    private val mLc: CcMaxApduDataSizeField = CcMaxApduDataSizeField.mLc(maxCommandSize ?: 0x00FF)

    init {
        require(fileDescriptors.isNotEmpty()) { "CapabilityContainer must have at least one file descriptor." }
        var totalTlvLength = 0
        for (descriptor in fileDescriptors) {
            totalTlvLength += descriptor.length
        }

        // Header is 7 bytes: CCLEN(2) + Version(1) + MLe(2) + MLc(2)
        val totalLength = 7 + totalTlvLength
        cclen = CcLenField(totalLength)

        // Register in order
        register(cclen)
        register(version)
        register(mLe)
        register(mLc)
        for (descriptor in fileDescriptors) {
            register(descriptor)
        }
    }
}
