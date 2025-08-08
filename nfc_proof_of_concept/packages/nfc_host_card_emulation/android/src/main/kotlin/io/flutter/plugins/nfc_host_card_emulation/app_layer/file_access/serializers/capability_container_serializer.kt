package io.flutter.plugins.nfc_host_card_emulation.file_access.serializers

import io.flutter.plugins.nfc_host_card_emulation.app_layer.ApduSerializer
import io.flutter.plugins.nfc_host_card_emulation.file_access.fields.*

class CapabilityContainer(
    private val fileDescriptors: List<FileControlTlv>,
    maxResponseSize: Int = 0x00FF,
    maxCommandSize: Int = 0x00FF
) : ApduSerializer("Capability Container") {

    lateinit var cclen: CcLenField
    private val version = CcMappingVersionField.v2_0
    private val mLe: CcMaxApduDataSizeField = CcMaxApduDataSizeField.mLe(maxResponseSize)
    private val mLc: CcMaxApduDataSizeField = CcMaxApduDataSizeField.mLc(maxCommandSize)

    init {
        require(fileDescriptors.isNotEmpty()) { "CapabilityContainer must have at least one file descriptor." }
    }

    override fun setFields() {
        val totalTlvLength = fileDescriptors.sumOf { it.length }
        
        // Header is 7 bytes: CLEN(2) + Version(1) + MLe(2) + MLc(2)
        val totalLength = 7 + totalTlvLength
        cclen = CcLenField(totalLength)

        fields = listOf(cclen, version, mLe, mLc) + fileDescriptors
    }
}