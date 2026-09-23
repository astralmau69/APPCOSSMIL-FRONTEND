---
name: entorno-build-android-linux
description: "Setup Android en la máquina Linux (Parrot, 7.5GB RAM, proyecto en NTFS) — SDK/JDK, límites de memoria Gradle y peculiaridades del disco"
metadata: 
  node_type: memory
  type: project
  originSessionId: c278de39-fa9a-454d-b373-4c26597e5e59
---

Entorno de build Android en la máquina Linux (configurado 2026-07-15):

- Android SDK en `~/Android/Sdk` (cmdline-tools, platform-tools/adb, platforms 34/35/36, build-tools 35/36, NDK 27.0.12077973). `ANDROID_HOME` y PATH en `~/.bashrc`.
- JDK 21 Temurin en `~/.jdks/jdk-21.0.11+10` — el Java 25 del sistema es incompatible con Gradle 8.12. Flutter apunta a ambos vía `flutter config --android-sdk --jdk-dir`.
- La máquina tiene **7.5 GB de RAM**: `android/gradle.properties` se bajó a `-Xmx3G` (estaba en 8G heredado de Windows y el daemon moría por OOM). No subirlo.
- El proyecto vive en `/mnt/Nuevo_vol` = **NTFS vía ntfs-3g (FUSE)**: builds lentos y fallos aleatorios ("Unable to delete directory", NoSuchFileException en zip-cache); `org.gradle.workers.max=2` mitiga. El proyecto venía copiado de Windows (`D:\app\Post2`) con `.dart_tool/` y `build/` sucios — si aparecen rutas `D:\` en errores de Gradle, correr `flutter clean`.
- **`build/` es un symlink a `~/.cache/post2-build` (ext4)** para sacar la E/S de Gradle del NTFS. Si `flutter clean` o un `rm -rf build` lo borra, recrearlo: `ln -sfn ~/.cache/post2-build /mnt/Nuevo_vol/app/Post2/build`.
- Tablet de pruebas: Samsung Galaxy Tab S7 FE (SM-T735), serial `R52W303P2BL`. Las reglas udev vienen de `android-sdk-platform-tools-common`; hubo que reiniciar `systemd-udevd` para que aplicaran.
