package com.ilbarslab.smartdiafon

import android.app.Activity
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Yönetici NFC etiketi yazma kanalı: "mobildiafon/nfc"
 *   isAvailable          -> { supported, enabled }
 *   writeUri { url }     -> etikete dokunulunca URI yazar; true döner (hata: PlatformException)
 *   cancel               -> beklemeyi iptal eder
 *
 * Reader mode açıkken etiket dokunuşu NfcDoorActivity'ye gitmez; yazma ekranında kapı açılmaz.
 */
class NfcWriter(private val activity: Activity, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, "mobildiafon/nfc")
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    val a = NfcAdapter.getDefaultAdapter(activity)
                    result.success(mapOf("supported" to (a != null), "enabled" to (a?.isEnabled == true)))
                }
                "writeUri" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) { result.error("ARG", "url gerekli", null); return@setMethodCallHandler }
                    startWrite(url, result)
                }
                "cancel" -> { stop(); finish { it.error("CANCELLED", "İptal edildi", null) }; result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun startWrite(url: String, result: MethodChannel.Result) {
        val adapter = NfcAdapter.getDefaultAdapter(activity)
        if (adapter == null) { result.error("NO_NFC", "Bu telefonda NFC yok", null); return }
        if (!adapter.isEnabled) { result.error("NFC_OFF", "NFC kapalı. Ayarlardan açın.", null); return }
        finish { it.error("CANCELLED", "Yeni yazma başladı", null) }
        pending = result
        val msg = NdefMessage(arrayOf(NdefRecord.createUri(url)))
        val flags = NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V
        adapter.enableReaderMode(activity, { tag -> write(tag, msg) }, flags, null)
    }

    private fun write(tag: Tag, msg: NdefMessage) {
        val err: String? = try {
            val ndef = Ndef.get(tag)
            if (ndef != null) {
                ndef.connect()
                try {
                    when {
                        !ndef.isWritable -> "Etiket yazmaya kapalı (kilitli)"
                        ndef.maxSize < msg.toByteArray().size -> "Etiket kapasitesi yetersiz"
                        else -> { ndef.writeNdefMessage(msg); null }
                    }
                } finally { try { ndef.close() } catch (_: Exception) {} }
            } else {
                val f = NdefFormatable.get(tag)
                if (f == null) "Bu etiket NDEF desteklemiyor"
                else {
                    f.connect()
                    try { f.format(msg); null } finally { try { f.close() } catch (_: Exception) {} }
                }
            }
        } catch (e: Exception) {
            "Yazılamadı, etiketi sabit tutup tekrar deneyin"
        }
        main.post { stop() }   // reader callback'i arka plan thread'inde gelir
        finish { if (err == null) it.success(true) else it.error("WRITE", err, null) }
    }

    private fun stop() {
        try { NfcAdapter.getDefaultAdapter(activity)?.disableReaderMode(activity) } catch (_: Exception) {}
    }

    private fun finish(block: (MethodChannel.Result) -> Unit) {
        val r = pending ?: return
        pending = null
        main.post { block(r) }
    }

    /** Ekran arka plana giderse beklemeyi iptal et (reader mode yalnızca ön planda çalışır). */
    fun onPause() {
        if (pending != null) { stop(); finish { it.error("CANCELLED", "Ekran kapandı", null) } }
    }
}
