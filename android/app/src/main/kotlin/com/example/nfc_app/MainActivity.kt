package com.example.nfc_app

import android.app.PendingIntent
import android.content.Intent
import android.nfc.NfcAdapter
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var nfcAdapter: NfcAdapter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Inicializar NFC Adapter
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        if (nfcAdapter == null) {
            Log.e("MainActivity", "Este dispositivo no tiene NFC")
        } else {
            Log.d("MainActivity", "NFC Adapter inicializado correctamente")
        }
    }

    override fun onResume() {
        super.onResume()

        // Habilitar foreground dispatch cuando la app está en primer plano
        nfcAdapter?.let { adapter ->
            val intent = Intent(this, javaClass).apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }

            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_MUTABLE
            )

            adapter.enableForegroundDispatch(this, pendingIntent, null, null)
            Log.d("MainActivity", "Foreground dispatch habilitado")
        }
    }

    override fun onPause() {
        super.onPause()

        // Deshabilitar foreground dispatch cuando la app sale de primer plano
        nfcAdapter?.let { adapter ->
            adapter.disableForegroundDispatch(this)
            Log.d("MainActivity", "Foreground dispatch deshabilitado")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        // Log cuando se detecta un tag NFC
        if (NfcAdapter.ACTION_TAG_DISCOVERED == intent.action ||
            NfcAdapter.ACTION_TECH_DISCOVERED == intent.action ||
            NfcAdapter.ACTION_NDEF_DISCOVERED == intent.action) {
            Log.d("MainActivity", "¡NFC TAG DETECTADO! Action: ${intent.action}")
        }
    }
}
