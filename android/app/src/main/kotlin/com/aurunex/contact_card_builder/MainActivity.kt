package com.aurunex.contact_card_builder

import android.content.ComponentName
import android.content.pm.PackageManager
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.tech.Ndef
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var receiver: MethodChannel.Result? = null
    private fun stopReceiving() {
        try { NfcAdapter.getDefaultAdapter(this)?.disableReaderMode(this) } catch (_: Exception) {}
        receiver?.error("cancelled","NFC receiving stopped.",null)
        receiver=null
    }
    private fun stopSharing() {
        ContactNfcService.clear()
        val adapter=NfcAdapter.getDefaultAdapter(this)
        if(adapter!=null && packageManager.hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION)) {
            try { CardEmulation.getInstance(adapter).unsetPreferredService(this) } catch (_: Exception) {}
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"metcue/nfc").setMethodCallHandler { call,result ->
            val adapter=NfcAdapter.getDefaultAdapter(this)
            val capable=adapter!=null && packageManager.hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION)
            when(call.method) {
                "readerAvailability" -> result.success(if(adapter==null)"unsupported" else if(adapter.isEnabled)"available" else "disabled")
                "stopReceive" -> { stopReceiving();result.success(null) }
                "receive" -> {
                    if(adapter?.isEnabled!=true) result.error("unavailable","Enable NFC to receive by tap.",null)
                    else {
                        stopReceiving();receiver=result
                        adapter.enableReaderMode(this,{ tag ->
                            var text: String?=null
                            try {
                                val ndef=Ndef.get(tag) ?: throw IllegalStateException("Not a contact card")
                                val cached=ndef.cachedNdefMessage
                                val message=if(cached!=null)cached else { ndef.connect();try{ndef.ndefMessage}finally{ndef.close()} }
                                val record=message?.records?.firstOrNull { it.tnf==NdefRecord.TNF_MIME_MEDIA && it.type.toString(Charsets.US_ASCII) in listOf("text/vcard","text/x-vcard") }
                                if(record!=null && record.payload.size<=6000) text=record.payload.toString(Charsets.UTF_8)
                            } catch (_: Exception) {}
                            runOnUiThread {
                                // Only complete the session that was active for this tag.
                                if(receiver === result) {
                                    receiver=null;adapter.disableReaderMode(this)
                                    if(text!=null) result.success(text) else result.error("invalid","This NFC tag does not contain a contact. Use QR instead.",null)
                                }
                            }
                        },NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B,null)
                    }
                }
                "availability" -> result.success(if(!capable)"unsupported" else if(adapter!!.isEnabled)"available" else "disabled")
                "stop" -> { stopSharing();result.success(null) }
                "start" -> {
                    val vcard=call.argument<String>("vcard")
                    if(!capable || adapter?.isEnabled!=true) { result.error("unavailable","Enable NFC on a supported Android phone.",null) }
                    else if(vcard==null || !vcard.startsWith("BEGIN:VCARD") || vcard.toByteArray(Charsets.UTF_8).size>6000) { result.error("invalid","Use the QR or contact file for this card.",null) }
                    else {
                        try {
                            val message=NdefMessage(arrayOf(NdefRecord.createMime("text/vcard",vcard.toByteArray(Charsets.UTF_8)))).toByteArray()
                            val preferred=CardEmulation.getInstance(adapter).setPreferredService(this,ComponentName(this,ContactNfcService::class.java))
                            if(!preferred) throw IllegalStateException("Could not start foreground NFC sharing.")
                            ContactNfcService.begin(message); result.success(null)
                        } catch(error:Exception) { stopSharing();result.error("unavailable",error.message,null) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onPause() { stopReceiving();stopSharing();super.onPause() }
    override fun onDestroy() { stopReceiving();stopSharing();super.onDestroy() }
}
