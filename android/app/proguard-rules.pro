# Flutter Secure Storage
-keep class com.it_monkey.flutter_secure_storage.** { *; }

# Local Auth / Biometrics
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }

# Audioplayers
-keep class xyz.luan.audioplayers.** { *; }

# General Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.editing.** { *; }

# Evitar warnings que bloquean R8 (common with various plugins)
-dontwarn android.hardware.biometrics.**
-dontwarn androidx.biometric.**
-dontwarn io.flutter.plugins.localauth.**
-dontwarn xyz.luan.audioplayers.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn com.google.android.gms.**
-dontwarn org.bouncycastle.**
-dontwarn com.google.android.play.core.**

# No optimizar (muchos plugins de Flutter fallan con optimización agresiva)
-dontoptimize
-dontobfuscate
