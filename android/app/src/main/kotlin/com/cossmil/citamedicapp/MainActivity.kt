package com.cossmil.citamedicapp

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
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
  }
}
