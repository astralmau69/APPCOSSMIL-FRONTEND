# ─── Flutter Engine ──────────────────────────────────────────────────────────
# El engine de Flutter usa reflection para registrar plugins. Sin estas reglas,
# R8 eliminaría clases del engine y la app crashearía en release.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ─── flutter_secure_storage ──────────────────────────────────────────────────
# Usa Android Keystore vía reflection — preservar las clases de cifrado.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ─── local_auth (biometría) ──────────────────────────────────────────────────
# BiometricPrompt usa callbacks vía reflection.
-keep class androidx.biometric.** { *; }

# ─── flutter_local_notifications ─────────────────────────────────────────────
-keep class com.dexterous.** { *; }

# ─── audioplayers ────────────────────────────────────────────────────────────
-keep class xyz.luan.audioplayers.** { *; }

# ─── geolocator ──────────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }

# ─── permission_handler ──────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ─── Kotlin Coroutines (usadas internamente por varios plugins) ───────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# ─── OkHttp / okio (dependencias transitivas de algunos plugins) ─────────────
-dontwarn okhttp3.**
-dontwarn okio.**

# ─── Modelos COSSMIL: preservar campos usados en fromJson/toJson ─────────────
# R8 puede eliminar campos que solo se acceden mediante cast de Map dinámico.
-keepclassmembers class com.cossmil.citamedicapp.** {
    public <init>(...);
    public *;
}

# ─── Stack traces legibles (para futuro Crashlytics / Sentry) ────────────────
# Descomentar si añades un servicio de crash reporting.
# -keepattributes SourceFile,LineNumberTable
# -renamesourcefileattribute SourceFile
