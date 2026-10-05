package com.ilbarslab.smartdiafon

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.nfc.NdefMessage
import android.nfc.NfcAdapter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.widget.Toast
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * NFC kapı etiketi: https://mobildiafon.com/web/nfc.html#t=<etiket>  (bina etiketi, önerilen)
 *                   https://mobildiafon.com/web/nfc.html#k=<anahtar> (eski gizli anahtar)
 *
 * Uygulama yüklüyse Android etiketi tarayıcı yerine buraya verir (App Links / NDEF_DISCOVERED).
 * Ekransız (şeffaf) çalışır. Bina etiketinde giriş token'ı ile /api/calls/nfc-tag'e POST eder;
 * sunucu kullanıcının binanın onaylı sakini/sahibi olduğunu kontrol eder. Sonuç Toast + titreşim.
 * Uygulaması olmayan telefonlarda aynı etiket web sayfasında (SMS girişiyle) çalışır.
 */
class NfcDoorActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        val frag = intent?.let { fragmentBul(it) }
        val tag = frag?.let { Regex("(?:^|&)t=([A-Za-z0-9_-]{8,40})").find(it)?.groupValues?.get(1) }
        val key = frag?.let { Regex("(?:^|&)k=([A-Za-z0-9_-]{24,64})").find(it)?.groupValues?.get(1) }
        val app = applicationContext

        if (tag != null) {
            // Bina etiketi: yetkiyi giriş yapmış kullanıcı verir (binanın onaylı sakini / sahibi)
            val token = app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.nfc_auth_token", null)
            if (token.isNullOrEmpty()) {
                goster(app, false, "Kapıyı açmak için MobilDiafon'a giriş yapın")
                startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                finish()
                return
            }
            Thread {
                val (ok, mesaj) = istek(API_TAG, JSONObject().put("tag", tag), token)
                Handler(Looper.getMainLooper()).post { goster(app, ok, mesaj) }
            }.start()
            finish()
            return
        }

        if (key == null) {
            goster(app, false, "Geçersiz etiket")
            finish()
            return
        }
        Thread {
            val (ok, mesaj) = istek(API, JSONObject().put("key", key), null)
            Handler(Looper.getMainLooper()).post { goster(app, ok, mesaj) }
        }.start()
        finish()
    }

    /** Etiketteki URI'nin # kısmını döndürür (t=... bina etiketi, k=... eski gizli anahtar). */
    private fun fragmentBul(intent: Intent): String? {
        var uri: Uri? = intent.data
        if (uri == null && Build.VERSION.SDK_INT >= 33) {
            val msgs = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES, NdefMessage::class.java)
            uri = msgs?.firstOrNull()?.records?.firstNotNullOfOrNull { it.toUri() }
        } else if (uri == null) {
            @Suppress("DEPRECATION")
            val msgs = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
            uri = (msgs?.firstOrNull() as? NdefMessage)?.records?.firstNotNullOfOrNull { it.toUri() }
        }
        return uri?.fragment
    }

    private fun istek(url: String, govde: JSONObject, token: String?): Pair<Boolean, String> {
        return try {
            val c = URL(url).openConnection() as HttpURLConnection
            c.requestMethod = "POST"
            c.connectTimeout = 8000
            c.readTimeout = 10000
            c.doOutput = true
            c.setRequestProperty("Content-Type", "application/json")
            if (token != null) c.setRequestProperty("Authorization", "Bearer $token")
            c.outputStream.use { it.write(govde.toString().toByteArray()) }
            if (c.responseCode == 401) return false to "Oturum süresi doldu, uygulamaya tekrar giriş yapın"
            val body = (if (c.responseCode in 200..299) c.inputStream else c.errorStream)
                ?.bufferedReader()?.use { it.readText() } ?: "{}"
            val j = JSONObject(body)
            val ok = j.optBoolean("success", false)
            ok to (if (ok) "Kapı açıldı" else j.optString("message", "Kapı açılamadı"))
        } catch (e: Exception) {
            false to "Bağlantı hatası"
        }
    }

    companion object {
        private const val API = "https://mobildiafon.com/api/calls/nfc-open"
        private const val API_TAG = "https://mobildiafon.com/api/calls/nfc-tag"

        private fun goster(ctx: Context, ok: Boolean, mesaj: String) {
            Toast.makeText(ctx, (if (ok) "🔓 " else "✕ ") + mesaj, Toast.LENGTH_SHORT).show()
            if (!ok) return
            try {
                val v = ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                if (Build.VERSION.SDK_INT >= 26) v.vibrate(VibrationEffect.createOneShot(150, VibrationEffect.DEFAULT_AMPLITUDE))
                else @Suppress("DEPRECATION") v.vibrate(150)
            } catch (_: Exception) {}
        }
    }
}
