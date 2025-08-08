package io.flutter.plugins.nfc_host_card_emulation.app_layer

typealias Bytes = ByteArray

abstract class ApduField(val name: String, size: Int) {
    var buffer: Bytes = Bytes(size)
        protected set

    val length: Int
        get() = buffer.size

    override fun toString(): String = buffer.joinToString(" ") {
        it.toUByte().toString(16).padStart(2, '0').uppercase()
    }
}

abstract class ApduSerializer(name: String) : ApduField(name, 0) {
    protected var fields: List<ApduField?> = emptyList()

    init {
        setFields()
        serialize()
    }

    protected abstract fun setFields()

    private fun serialize() {
        val outputStream = java.io.ByteArrayOutputStream()
        fields.filterNotNull().forEach { field ->
            outputStream.write(field.buffer)
        }
        this.buffer = outputStream.toByteArray()
    }

    override fun toString(): String {
        return fields.filterNotNull().joinToString("") { field ->
            " | ${field.name}: ${field.toString()}"
        }
    }
}

class ApduData(name: String, data: Bytes) : ApduField(name, data.size) {
    init {
        this.buffer = data.copyOf()
    }
}