# 🔐 CREDENCIALES Y FIRMA DE LA APP COSSMIL

> [!IMPORTANT]
> **ESTE DOCUMENTO ES CRÍTICO.** Contiene las contraseñas y la explicación del certificado (`.jks`) que enlaza esta aplicación con la Google Play Store. **Si pierdes el archivo `.jks` o estas credenciales, no podrás subir ninguna actualización futura a la Google Play Console.**

## 📂 Archivos Generados

1. **La Aplicación Compilada (Para subir HOY a Play Console):**
   - **Archivo:** `app-release.aab`
   - **Ruta:** `build/app/outputs/bundle/release/app-release.aab`
   - *Este es el único archivo binario que arrastras a la página de Google Play Console.*

2. **La Llave Maestra / Sello Digital (Para respaldar YA MISMO):**
   - **Archivo:** `upload-keystore.jks`
   - **Ruta:** `android/upload-keystore.jks`
   - *Esta llave es la firma de propiedad criptográfica exclusiva de COSSMIL. Respáldala en la nube ahora.*

---

## 🔑 Credenciales del Keystore

Guarden estos datos junto con la cuenta de desarrollador. Las contraseñas están unificadas para evitar confusiones.

- **Alias de la Llave (Key Alias) :** `upload`
- **Store Password (Key Store)   :** `cossmil2026`
- **Key Password (Key)           :** `cossmil2026`

---

## 🚀 ¿Cómo funcionan las futuras actualizaciones?

Para la próxima versión (por ejemplo, después de unos meses):
1. Asegúrense de que el archivo `upload-keystore.jks` sigue dentro de la carpeta `android/` en la computadora de quien programe.
2. Aumenten el número de versión en el archivo `pubspec.yaml` (ej. de `1.0.2+3` a `1.0.3+4`).
3. Ejecuten el comando estándar y la aplicación se auto-firmará:

```bash
flutter build appbundle
```

¡Y listo! Eso generará de manera invisible un nuevo `.aab` válido que Google Play reconocerá inmediatamente como una actualización legítima firmada por COSSMIL.
