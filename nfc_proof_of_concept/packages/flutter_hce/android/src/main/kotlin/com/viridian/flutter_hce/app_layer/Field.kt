package com.viridian.flutter_hce.app_layer

typealias Bytes = ByteArray

abstract class ApduField(val name: String, initialSize: Int) {
    protected var _buffer: Bytes = ByteArray(initialSize)
    open val buffer: Bytes
        get() = _buffer;

    open val length: Int
        get() = _buffer.size;

    protected fun setBuffer(newBytes: Bytes) {
        _buffer = newBytes.copyOf()
    }

    override fun toString(): String =
        buffer.joinToString(" ") { "%02X".format(it.toLong() and 0xFF) }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ApduField) return false
        return buffer.contentEquals(other.buffer)
    }

    override fun hashCode(): Int = buffer.contentHashCode()
}

abstract class ApduSerializer(name: String) : ApduField(name, 0) {
    private val fields: MutableList<ApduField?> = mutableListOf()

    protected fun <T : ApduField?> register(field: T): T {
        fields.add(field)
        return field
    }

    final override val buffer: Bytes
        get(){
            serialize();
            return _buffer;
        }

    final override val length: Int
        get(){
            var res = 0;
            for(currField in fields){
                res += currField?.length ?: 0;
            }
            return res;
        }

    final fun serialize(){
        val result = ByteArray(this.length)
        var offset = 0
        
        for (field in fields) {
            if (field != null) {
                val fieldBytes = field.buffer
                System.arraycopy(fieldBytes, 0, result, offset, fieldBytes.size)
                offset += fieldBytes.size
            }
        }
        _buffer = result;
    }

    override fun toString(): String =
        fields.mapNotNull { field -> field?.let { " | ${it.name}: $it" } }.joinToString("")
}

open class ApduData(data: Bytes, name: String) : ApduField(name, data.size) {
    init {
        setBuffer(data)
    }
}
