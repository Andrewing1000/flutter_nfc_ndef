package com.viridian.flutter_hce.app_layer

import java.nio.ByteBuffer

typealias Bytes = ByteArray

abstract class ApduField(val name: String, initialSize: Int) {
    protected var buffer: Bytes = ByteArray(initialSize)
    protected var size: Int = initialSize

    val length: Int get() = size
    
    open fun toByteArray(): Bytes {
        return buffer.copyOf(size)
    }

    override fun toString(): String {
        return buffer.take(size).joinToString(" ") { "%02X".format(it) }
    }
}

abstract class ApduSerializer(name: String, initialSize: Int = 0) : ApduField(name, initialSize) {
    protected val fields: MutableList<ApduField?> = mutableListOf()

    init {
        setFields()
        serialize()
    }

    /**
     * Populates the `fields` list with all potential fields for serialization.
     * Null values will be ignored during serialization.
     */
    abstract fun setFields()

    override fun toByteArray(): Bytes {
        serialize()
        return super.toByteArray()
    }

    private fun serialize() {
        val builder = mutableListOf<Byte>()
        for (field in fields) {
            if (field != null) {
                builder.addAll(field.toByteArray().toList())
            }
        }
        buffer = builder.toByteArray()
        size = buffer.size
    }

    override fun toString(): String {
        return fields.mapNotNull { field ->
            field?.let { " | ${it.name}: $it" }
        }.joinToString("")
    }
}

open class ApduData(data: Bytes, name: String) : ApduField(name, data.size) {
    init {
        buffer = data.copyOf()
    }
}
