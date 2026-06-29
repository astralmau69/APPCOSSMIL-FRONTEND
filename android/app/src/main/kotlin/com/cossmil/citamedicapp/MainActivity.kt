package com.cossmil.citamedicapp

import android.content.Context
import android.media.AudioManager
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    // Edge-to-edge obligatorio en Android 15 (API 35). Llamar ANTES de
    // super.onCreate() declara la actividad como edge-to-edge: hace que
    // setStatusBarColor / setNavigationBarColor / setNavigationBarDividerColor
    // (que Flutter aún invoca desde PlatformPlugin.setSystemChromeSystemUIOverlayStyle)
    // sean no-op en API 35+, eliminando el aviso de APIs obsoletas en Play Store
    // sin perder compatibilidad con APIs anteriores.
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cossmil.audio/ringer")
      .setMethodCallHandler { call, result ->
        if (call.method == "getRingerMode") {
          val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
          // 0 = RINGER_MODE_SILENT, 1 = RINGER_MODE_VIBRATE, 2 = RINGER_MODE_NORMAL
          result.success(am.ringerMode)
        } else {
          result.notImplemented()
        }
      }

    // Bloqueo de capturas/grabación de pantalla (FLAG_SECURE) para el carnet.
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cossmil.security/screenshot")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "enableSecure" -> {
            window.setFlags(
              WindowManager.LayoutParams.FLAG_SECURE,
              WindowManager.LayoutParams.FLAG_SECURE
            )
            result.success(true)
          }
          "disableSecure" -> {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            result.success(true)
          }
          else -> result.notImplemented()
        }
      }
  }
}
