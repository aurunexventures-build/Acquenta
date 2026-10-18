package com.aurunex.contact_card_builder

/** Minimal read-only NFC Forum Type 4 NDEF application, independently testable. */
class NdefCardProtocol(private val message: ByteArray) {
    private var selected = 0
    private var applicationSelected = false
    private val success = byteArrayOf(0x90.toByte(), 0)
    private val missing = byteArrayOf(0x6A, 0x82.toByte())
    private val invalid = byteArrayOf(0x67, 0)
    private val aid = byteArrayOf(0xD2.toByte(), 0x76, 0, 0, 0x85.toByte(), 1, 1)
    // CC length, mapping v2.0, MLe=255, MLc=255, NDEF file E104, max=8192, read-only.
    private val capability = byteArrayOf(0,15,0x20,0,0xFF.toByte(),0,0xFF.toByte(),4,6,0xE1.toByte(),4,0x20,0,0,0xFF.toByte())
    fun process(command: ByteArray): ByteArray {
        if (command.size < 4 || command[0].toInt() != 0) return invalid
        val instruction = command[1].toInt() and 255
        if (instruction == 0xA4) {
            if (command.size < 5) return invalid
            val count = command[4].toInt() and 255
            if (command.size < 5+count) return invalid
            val data = command.copyOfRange(5,5+count)
            if (command[2].toInt() == 4) {
                applicationSelected = data.contentEquals(aid)
                selected = 0
                return if (applicationSelected) success else missing
            }
            if (!applicationSelected || command[2].toInt() != 0 || count != 2) return missing
            selected = ((data[0].toInt() and 255) shl 8) or (data[1].toInt() and 255)
            return if (selected == 0xE103 || selected == 0xE104) success else missing
        }
        if (instruction == 0xB0) {
            if (!applicationSelected || command.size != 5) return invalid
            val source = when (selected) {
                0xE103 -> capability
                0xE104 -> byteArrayOf((message.size shr 8).toByte(),message.size.toByte())+message
                else -> return missing
            }
            val offset = ((command[2].toInt() and 255) shl 8) or (command[3].toInt() and 255)
            val length = (command[4].toInt() and 255).let { if(it==0)256 else it }
            if (offset >= source.size) return byteArrayOf(0x6B,0)
            return source.copyOfRange(offset,minOf(offset+length,source.size))+success
        }
        return byteArrayOf(0x6D,0)
    }
}
