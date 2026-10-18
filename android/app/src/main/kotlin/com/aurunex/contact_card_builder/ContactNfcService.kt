package com.aurunex.contact_card_builder

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.os.SystemClock

class ContactNfcService : HostApduService() {
    companion object {
        @Volatile private var message: ByteArray? = null
        @Volatile private var expiresAt = 0L
        fun begin(bytes: ByteArray) { message=bytes.copyOf(); expiresAt=SystemClock.elapsedRealtime()+120000 }
        fun clear() { message=null; expiresAt=0 }
    }
    private var protocol: NdefCardProtocol? = null
    private var current: ByteArray? = null
    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        val data=message
        if(data==null || SystemClock.elapsedRealtime()>expiresAt || commandApdu==null) {
            clear();protocol=null;current=null;return byteArrayOf(0x6A,0x82.toByte())
        }
        if(current !== data) { protocol=NdefCardProtocol(data);current=data }
        return protocol!!.process(commandApdu)
    }
    override fun onDeactivated(reason: Int) { protocol=null;current=null }
}
