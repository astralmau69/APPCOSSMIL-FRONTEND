import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../utils/web_local_storage.dart';

/// Capacidad biométrica real del dispositivo.
///
/// [available]   → hardware presente Y biometría enrollada → puede usarse ahora.
/// [notEnrolled] → hardware presente pero sin huellas/face registradas en el sistema.
/// [unavailable] → sin hardware biométrico o dispositivo no compatible.
enum DeviceBiometricStatus { available, notEnrolled, unavailable }

/// Resultado granular de un intento de autenticación biométrica.
///
/// Permite a la UI reaccionar de forma distinta según el motivo:
///   - [success]   → identidad verificada.
///   - [cancelled] → el usuario canceló o tocó el botón negativo del prompt.
///   - [lockedOut] → el SO bloqueó el sensor por demasiados intentos fallidos
///                   (temporal o permanente). Debe forzarse el PIN de la app.
///   - [failure]   → error de plataforma, sin hardware, no enrollado, etc.
enum BiometricAuthResult { success, cancelled, lockedOut, failure }

/// Gestiona la seguridad local: PIN de 4 dígitos, biometría y cooldown.
///
/// Separación clara de responsabilidades:
///   - Autenticación remota  → AuthService
///   - Sesión persistida     → TokenStorage
///   - PIN local             → SecurityService (hash SHA-256)
///   - Biometría             → SecurityService (local_auth)
///   - Cooldown / intentos   → SecurityService (persistido)
///   - Estado bloqueo/resume → TabShell (lifecycle)
///   - Inactividad / gracia  → SecurityService (timestamps persistidos)
class SecurityService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'cossmil_secure_prefs',
    ),
    iOptions: IOSOptions(
      // first_unlock: el dato sobrevive reinicios y queda accesible tras el
      // primer desbloqueo del día. Sin esto (default 'unlocked') una lectura
      // en momentos sensibles tras el boot puede fallar.
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  static final _localAuth = LocalAuthentication();

  // ── Acceso a almacenamiento con soporte web ────────────────────────────
  // En web, flutter_secure_storage cifra con window.crypto.subtle, que SOLO
  // existe en contextos seguros (https o localhost). Servida por http://IP
  // (LAN interna) esa API es undefined y CUALQUIER write revienta el flujo
  // de login sin error visible. En web se usa localStorage: aquí solo viven
  // hash+salt del PIN, flags y timestamps — nada reversible a la contraseña.
  static Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      webLsSet(key, value);
      return;
    }
    await _storage.write(key: key, value: value);
  }

  static Future<void> _delete(String key) async {
    if (kIsWeb) {
      webLsDel(key);
      return;
    }
    await _storage.delete(key: key);
  }

  /// Lee una clave del almacenamiento seguro con reintentos.
  ///
  /// Tras reiniciar el dispositivo, la primera lectura del Keystore puede
  /// fallar de forma transitoria (Keystore aún no listo / Direct Boot) en
  /// varios dispositivos Android. Reintentar evita que ese fallo pasajero se
  /// interprete como "sin credenciales" y termine reseteando el PIN/huella.
  ///
  /// Importante: una clave inexistente devuelve `null` SIN lanzar excepción,
  /// por lo que el caso normal "sin PIN" no reintenta ni se ralentiza. Solo se
  /// reintenta ante un error real de descifrado/lectura. Si tras los reintentos
  /// el error persiste, se relanza para que el llamador NO asuma "sin PIN".
  static Future<String?> _readResilient(String key, {int retries = 2}) async {
    if (kIsWeb) return webLsGet(key); // localStorage: sin Keystore ni reintentos
    for (int attempt = 0; ; attempt++) {
      try {
        return await _storage.read(key: key);
      } catch (e) {
        if (attempt >= retries) rethrow;
        await Future.delayed(Duration(milliseconds: 150 * (attempt + 1)));
      }
    }
  }

  static const _keyPin            = 'local_pin_hash';
  static const _keyPinSalt        = 'local_pin_salt';
  static const _keyUseBiometrics  = 'use_biometrics';
  static const _keyCooldownUntil  = 'pin_cooldown_until';
  static const _keyFailedAttempts = 'pin_failed_attempts';
  static const _keyLockoutCount   = 'pin_lockout_count';
  static const _keyDisplayName    = 'user_display_name';
  static const _keyLastBackground = 'last_background_ts';
  static const _keyLastActivity   = 'last_activity_ts';

  // Salt estático de app — evita que hashes idénticos entre distintas apps (usado como fallback heredado).
  static const _pinSalt = 'cossmil_sec_v1_';

  // ─── Constantes configurables ──────────────────────────────────────────────

  /// Intentos fallidos antes de activar el cooldown.
  static const maxPinAttempts = 5;

  /// Duración del bloqueo temporal tras agotar los intentos.
  static const cooldownDuration = Duration(seconds: 30);

  /// Ventana de gracia al volver desde background: si la app vuelve
  /// en menos de este tiempo, NO se pide desbloqueo. Se mantiene amplia (45 s)
  /// para que cambiar brevemente a otra app (copiar un código, ver un mensaje)
  /// no resulte en un bloqueo brusco al regresar.
  static const graceWindowDuration = Duration(seconds: 45);

  /// Tiempo de inactividad del usuario antes de bloquear la app (usuarios con PIN).
  static const inactivityTimeout = Duration(minutes: 2);

  /// Tiempo de inactividad antes de cerrar la sesión completamente
  /// cuando el usuario NO tiene PIN/biométrica configurado.
  static const sessionTimeoutNoPinDuration = Duration(minutes: 10);

  // ─── PIN ───────────────────────────────────────────────────────────────────

  /// Deriva una clave usando PBKDF2 con HMAC-SHA256.
  static Uint8List _pbkdf2(String password, Uint8List salt, int iterations, int keyLength) {
    final mac = Hmac(sha256, utf8.encode(password));
    final numBlocks = (keyLength + 31) ~/ 32;
    final result = BytesBuilder();

    for (int i = 1; i <= numBlocks; i++) {
      final blockIndexBytes = ByteData(4)..setInt32(0, i, Endian.big);
      final saltWithBlockIndex = Uint8List(salt.length + 4)
        ..setAll(0, salt)
        ..setAll(salt.length, blockIndexBytes.buffer.asUint8List());

      var u = mac.convert(saltWithBlockIndex).bytes;
      var t = Uint8List.fromList(u);

      for (int j = 2; j <= iterations; j++) {
        u = mac.convert(u).bytes;
        for (int k = 0; k < 32; k++) {
          t[k] ^= u[k];
        }
      }
      result.add(t);
    }

    return result.toBytes().sublist(0, keyLength);
  }

  /// Genera un Salt dinámico aleatorio y seguro para criptografía.
  static Uint8List _generateSecureSalt([int length = 16]) {
    final random = Random.secure();
    final salt = Uint8List(length);
    for (int i = 0; i < length; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  /// Deriva un hash SHA-256 legacy del PIN (para migración transparente).
  static String _hashPinLegacy(String pin) {
    final bytes = utf8.encode('$_pinSalt$pin');
    return sha256.convert(bytes).toString();
  }

  /// true si ya hay un PIN configurado.
  ///
  /// Si la lectura del Keystore falla de forma persistente (no es que falte el
  /// PIN, sino que no se pudo leer), se relanza la excepción a propósito: el
  /// llamador debe tratarlo como "no se pudo verificar" y caer en su ruta
  /// segura (login conservando el PIN), nunca como "no hay PIN" (que resetearía
  /// el patrón/huella del usuario).
  static Future<bool> hasPin() async {
    final value = await _readResilient(_keyPin);
    return value != null && value.isNotEmpty;
  }

  /// Guarda el PIN derivando una clave con PBKDF2 y un salt dinámico único.
  /// Lanza [Exception] si el PIN no tiene exactamente 4 dígitos numéricos.
  static Future<void> savePin(String pin) async {
    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw Exception('El PIN debe contener exactamente 4 dígitos numéricos');
    }
    
    // Generar un salt dinámico nuevo
    final salt = _generateSecureSalt();
    final derivedBytes = _pbkdf2(pin, salt, 10000, 32);
    
    // Almacenar el Salt dinámico en Base64 y el hash derivado en Secure Storage
    await _write(_keyPinSalt, base64.encode(salt));
    await _write(_keyPin, base64.encode(derivedBytes));
  }

  /// Compara el PIN ingresado contra el hash guardado, soportando migración desde hash legacy.
  static Future<bool> verifyPin(String pin) async {
    final savedHash = await _readResilient(_keyPin);
    if (savedHash == null || savedHash.isEmpty) return false;

    final savedSaltBase64 = await _readResilient(_keyPinSalt);
    
    // Si no hay salt almacenado, pero sí hay hash, es un PIN legacy (SHA-256 estático)
    if (savedSaltBase64 == null || savedSaltBase64.isEmpty) {
      final legacyHash = _hashPinLegacy(pin);
      if (savedHash == legacyHash) {
        // Migración automática al nuevo estándar PBKDF2 + Salt dinámico
        await savePin(pin);
        return true;
      }
      return false;
    }

    try {
      final salt = base64.decode(savedSaltBase64);
      final derivedBytes = _pbkdf2(pin, salt, 10000, 32);
      final calculatedHash = base64.encode(derivedBytes);
      return savedHash == calculatedHash;
    } catch (_) {
      return false;
    }
  }

  // ─── Cooldown / Intentos fallidos ─────────────────────────────────────────

  /// Retorna el número de intentos fallidos acumulados.
  static Future<int> getFailedAttempts() async {
    final v = await _readResilient(_keyFailedAttempts);
    return int.tryParse(v ?? '0') ?? 0;
  }

  /// Registra un intento fallido y activa el cooldown si se alcanzó [maxPinAttempts].
  /// Retorna el conteo actualizado de intentos fallidos.
  static Future<int> recordFailedAttempt() async {
    final current = await getFailedAttempts();
    final next = current + 1;
    await _write(_keyFailedAttempts, next.toString());
    if (next >= maxPinAttempts) {
      // Bloqueo ESCALONADO: cada bloqueo dura más que el anterior, para que la
      // fuerza bruta de un PIN de 4 dígitos sea impracticable (anti brute-force).
      final lockouts =
          (int.tryParse(await _readResilient(_keyLockoutCount) ?? '0') ?? 0) + 1;
      await _write(_keyLockoutCount, lockouts.toString());
      final until = DateTime.now().add(_escalatingCooldown(lockouts));
      await _write(
        _keyCooldownUntil,
        until.millisecondsSinceEpoch.toString(),
      );
      // Reiniciar la ventana de intentos; el conteo de bloqueos PERSISTE para
      // escalar el siguiente cooldown.
      await _delete(_keyFailedAttempts);
    }
    return next;
  }

  /// Duración del bloqueo según cuántas veces ya se bloqueó: 30s, 1m, 2m, 4m…
  /// hasta un tope de 30 minutos.
  static Duration _escalatingCooldown(int lockouts) {
    final shift = (lockouts - 1).clamp(0, 6);
    final secs = (cooldownDuration.inSeconds * (1 << shift)).clamp(30, 1800);
    return Duration(seconds: secs);
  }

  /// Reinicia COMPLETAMENTE el estado de intentos (intentos, cooldown y conteo
  /// de bloqueos). Llamar siempre tras un desbloqueo exitoso.
  static Future<void> resetFailedAttempts() async {
    await _delete(_keyFailedAttempts);
    await _delete(_keyCooldownUntil);
    await _delete(_keyLockoutCount);
  }

  /// Retorna el tiempo restante de cooldown, o null si no hay cooldown activo.
  /// Al expirar permite reintentar (limpia cooldown e intentos), pero CONSERVA
  /// el conteo de bloqueos para escalar el próximo bloqueo.
  static Future<Duration?> cooldownRemaining() async {
    final v = await _readResilient(_keyCooldownUntil);
    if (v == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) {
      await _delete(_keyCooldownUntil);
      await _delete(_keyFailedAttempts);
      return null;
    }
    return remaining;
  }

  /// true si hay un cooldown activo en este momento.
  static Future<bool> isInCooldown() async =>
      (await cooldownRemaining()) != null;

  // ─── Biometría ─────────────────────────────────────────────────────────────

  /// Retorna el estado real de biometría del dispositivo.
  static Future<DeviceBiometricStatus> getDeviceBiometricStatus() async {
    if (kIsWeb) return DeviceBiometricStatus.unavailable;
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) return DeviceBiometricStatus.unavailable;

      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return DeviceBiometricStatus.notEnrolled;

      final available = await _localAuth.getAvailableBiometrics();
      if (available.isEmpty) return DeviceBiometricStatus.notEnrolled;

      return DeviceBiometricStatus.available;
    } on PlatformException {
      return DeviceBiometricStatus.unavailable;
    }
  }

  /// Compatibilidad con código existente: retorna true si biometría está disponible Y enrollada.
  static Future<bool> canCheckBiometrics() async =>
      (await getDeviceBiometricStatus()) == DeviceBiometricStatus.available;

  /// Lista de tipos biométricos disponibles en el dispositivo.
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return <BiometricType>[];
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  /// Retorna una etiqueta legible para el tipo de biometría principal del dispositivo.
  /// Ejemplos: "Huella dactilar", "Face ID", "Iris", "Biometría".
  static Future<String> getBiometricLabel() async {
    final types = await getAvailableBiometrics();
    if (types.contains(BiometricType.face)) return 'Face ID';
    if (types.contains(BiometricType.fingerprint)) return 'Huella dactilar';
    if (types.contains(BiometricType.iris)) return 'Iris';
    return 'Biometría';
  }

  /// Retorna 'face' si el dispositivo usa reconocimiento facial, 'fingerprint' en otro caso.
  static Future<String> getBiometricIconKey() async {
    final types = await getAvailableBiometrics();
    if (types.contains(BiometricType.face)) return 'face';
    return 'fingerprint';
  }

  /// Activa o desactiva el uso de biometría como método de desbloqueo.
  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _write(_keyUseBiometrics, enabled.toString());
  }

  /// true si el usuario tiene biometría habilitada como método de desbloqueo.
  ///
  /// Usa lectura con reintentos para no perder la preferencia de huella por un
  /// fallo transitorio del Keystore tras reiniciar el dispositivo.
  static Future<bool> isBiometricsEnabled() async {
    final value = await _readResilient(_keyUseBiometrics);
    return value == 'true';
  }

  /// Retorna true si hay seguridad local configurada (PIN **o** biometría).
  ///
  /// CLAVE para que el PIN/huella "no se pierda nunca": si la lectura del PIN
  /// falla (Keystore no disponible momentáneamente), se asume que SÍ existe en
  /// vez de degradar a "sin seguridad". Así el arranque nunca cae al login
  /// normal por un fallo de lectura cuando el usuario ya configuró su PIN/huella.
  /// Solo se pierde al cerrar sesión o desinstalar (que borran el storage).
  static Future<bool> isLocalAuthConfiguredSafe() async {
    bool pin;
    try {
      pin = await hasPin();
    } catch (_) {
      return true; // no se pudo leer el PIN → asumir configurado (no degradar)
    }
    if (pin) return true;
    try {
      return await isBiometricsEnabled();
    } catch (_) {
      return true; // no se pudo leer la huella → asumir configurado
    }
  }

  /// Lanza el prompt nativo de biometría.
  /// Retorna un [BiometricAuthResult] que representa el resultado o error granular.
  static Future<BiometricAuthResult> authenticateWithBiometrics({
    String reason = 'Desbloquea tu aplicación COSSMIL',
  }) async {
    if (kIsWeb) return BiometricAuthResult.failure;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true, // Forzar fallback al PIN de nuestra app
        ),
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Seguridad COSSMIL',
            cancelButton: 'Cancelar',
            biometricHint: 'Verifica tu identidad',
            biometricNotRecognized: 'No reconocido. Intenta de nuevo.',
            biometricSuccess: '¡Verificado!',
            deviceCredentialsRequiredTitle: 'Usa tu PIN',
            deviceCredentialsSetupDescription: 'Configura un bloqueo de pantalla.',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancelar',
            goToSettingsButton: 'Ajustes',
            goToSettingsDescription: 'Por favor, configura la biometría en los ajustes.',
            lockOut: 'Demasiados intentos. Usa tu PIN.',
          ),
        ],
      );
      return authenticated ? BiometricAuthResult.success : BiometricAuthResult.cancelled;
    } on PlatformException catch (e) {
      if (e.code == auth_error.lockedOut || 
          e.code == auth_error.permanentlyLockedOut ||
          e.code == 'LockedOut' ||
          e.code == 'PermanentlyLockedOut') {
        return BiometricAuthResult.lockedOut;
      }
      return BiometricAuthResult.failure;
    }
  }

  // ─── Nombre de usuario para pantalla de desbloqueo ────────────────────────

  /// Guarda el nombre de display del usuario autenticado.
  /// Llamar desde AuthService tras un login exitoso.
  static Future<void> saveDisplayName(String name) async {
    await _write(_keyDisplayName, name);
  }

  /// Retorna el nombre guardado del usuario, o null si no existe.
  static Future<String?> getDisplayName() async {
    final v = await _readResilient(_keyDisplayName);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  // ─── Ventana de gracia al volver desde background ─────────────────────────

  /// Registra el momento exacto en que la app fue a background (paused).
  static Future<void> recordBackground() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _write(_keyLastBackground, now.toString());
  }

  /// Retorna true si el tiempo en background superó la [graceWindowDuration].
  /// Si no hay timestamp guardado → asume que debe bloquear (primera vez o reinicio).
  /// Si ya está expirado → debe bloquear.
  static Future<bool> shouldLockOnResume() async {
    final v = await _readResilient(_keyLastBackground);
    if (v == null) return false; // No hay registro de background → no bloquear
    final backgroundAt = DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    final elapsed = DateTime.now().difference(backgroundAt);
    return elapsed > graceWindowDuration;
  }

  /// Borra el timestamp de background después de que el usuario se autenticó
  /// correctamente, evitando que futuras transiciones `resumed` vuelvan a
  /// disparar el bloqueo dentro de la misma sesión activa.
  static Future<void> clearBackground() async {
    await _delete(_keyLastBackground);
  }

  /// Retorna true si el usuario SIN PIN ha estado minimizado en background
  /// por más tiempo del permitido por [sessionTimeoutNoPinDuration].
  static Future<bool> shouldLogoutOnResumeNoPin() async {
    final v = await _readResilient(_keyLastBackground);
    if (v == null) return false;
    final backgroundAt = DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    final elapsed = DateTime.now().difference(backgroundAt);
    return elapsed > sessionTimeoutNoPinDuration;
  }

  // ─── Bloqueo por inactividad ───────────────────────────────────────────────

  /// Actualiza el timestamp de última actividad real del usuario.
  static Future<void> recordActivity() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _write(_keyLastActivity, now.toString());
  }

  /// Retorna true si el usuario lleva más de [inactivityTimeout] sin interactuar.
  /// Solo aplica cuando hay PIN/biométrica configurada (bloqueo local).
  static Future<bool> shouldLockOnInactivity() async {
    final hasPin = await SecurityService.hasPin();
    if (!hasPin) return false;
    final v = await _readResilient(_keyLastActivity);
    if (v == null) return false; // Sin registro → no bloquear
    final lastActivity = DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    final elapsed = DateTime.now().difference(lastActivity);
    return elapsed > inactivityTimeout;
  }

  /// Retorna true si el usuario SIN PIN lleva más de [sessionTimeoutNoPinDuration]
  /// sin interactuar. En ese caso, la sesión debe cerrarse completamente (logout).
  static Future<bool> shouldLogoutOnInactivity() async {
    final hasPin = await SecurityService.hasPin();
    if (hasPin) return false; // Con PIN → se usa shouldLockOnInactivity()
    final v = await _readResilient(_keyLastActivity);
    if (v == null) return false;
    final lastActivity = DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    final elapsed = DateTime.now().difference(lastActivity);
    return elapsed > sessionTimeoutNoPinDuration;
  }

  // ─── Limpieza total ────────────────────────────────────────────────────────

  /// Elimina PIN, salt, preferencia biométrica, datos de cooldown, nombre y timestamps.
  /// Se llama siempre al hacer logout.
  static Future<void> clearSecurityData() async {
    await _delete(_keyPin);
    await _delete(_keyPinSalt);
    await _delete(_keyUseBiometrics);
    await _delete(_keyCooldownUntil);
    await _delete(_keyFailedAttempts);
    await _delete(_keyDisplayName);
    await _delete(_keyLastBackground);
    await _delete(_keyLastActivity);
  }
}
