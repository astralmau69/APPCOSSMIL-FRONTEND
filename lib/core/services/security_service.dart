import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Capacidad biométrica real del dispositivo.
///
/// [available]   → hardware presente Y biometría enrollada → puede usarse ahora.
/// [notEnrolled] → hardware presente pero sin huellas/face registradas en el sistema.
/// [unavailable] → sin hardware biométrico o dispositivo no compatible.
enum DeviceBiometricStatus { available, notEnrolled, unavailable }

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
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final _localAuth = LocalAuthentication();

  static const _keyPin            = 'local_pin_hash';
  static const _keyUseBiometrics  = 'use_biometrics';
  static const _keyCooldownUntil  = 'pin_cooldown_until';
  static const _keyFailedAttempts = 'pin_failed_attempts';
  static const _keyDisplayName    = 'user_display_name';
  static const _keyLastBackground = 'last_background_ts';
  static const _keyLastActivity   = 'last_activity_ts';

  // Salt estático de app — evita que hashes idénticos entre distintas apps.
  static const _pinSalt = 'cossmil_sec_v1_';

  // ─── Constantes configurables ──────────────────────────────────────────────

  /// Intentos fallidos antes de activar el cooldown.
  static const maxPinAttempts = 5;

  /// Duración del bloqueo temporal tras agotar los intentos.
  static const cooldownDuration = Duration(seconds: 30);

  /// Ventana de gracia al volver desde background: si la app vuelve
  /// en menos de este tiempo, NO se pide desbloqueo.
  static const graceWindowDuration = Duration(seconds: 15);

  /// Tiempo de inactividad del usuario antes de bloquear la app.
  static const inactivityTimeout = Duration(minutes: 2);

  // ─── PIN ───────────────────────────────────────────────────────────────────

  /// Deriva un hash SHA-256 del PIN. Nunca se persiste en texto plano.
  static String _hashPin(String pin) {
    final bytes = utf8.encode('$_pinSalt$pin');
    return sha256.convert(bytes).toString();
  }

  /// true si ya hay un PIN configurado.
  static Future<bool> hasPin() async {
    final value = await _storage.read(key: _keyPin);
    return value != null && value.isNotEmpty;
  }

  /// Guarda el PIN como hash SHA-256.
  /// Lanza [Exception] si el PIN no tiene exactamente 4 dígitos numéricos.
  static Future<void> savePin(String pin) async {
    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw Exception('El PIN debe contener exactamente 4 dígitos numéricos');
    }
    await _storage.write(key: _keyPin, value: _hashPin(pin));
  }

  /// Compara el PIN ingresado contra el hash guardado.
  static Future<bool> verifyPin(String pin) async {
    final savedHash = await _storage.read(key: _keyPin);
    if (savedHash == null || savedHash.isEmpty) return false;
    return savedHash == _hashPin(pin);
  }

  // ─── Cooldown / Intentos fallidos ─────────────────────────────────────────

  /// Retorna el número de intentos fallidos acumulados.
  static Future<int> getFailedAttempts() async {
    final v = await _storage.read(key: _keyFailedAttempts);
    return int.tryParse(v ?? '0') ?? 0;
  }

  /// Registra un intento fallido y activa el cooldown si se alcanzó [maxPinAttempts].
  /// Retorna el conteo actualizado de intentos fallidos.
  static Future<int> recordFailedAttempt() async {
    final current = await getFailedAttempts();
    final next = current + 1;
    await _storage.write(key: _keyFailedAttempts, value: next.toString());
    if (next >= maxPinAttempts) {
      final until = DateTime.now().add(cooldownDuration);
      await _storage.write(
        key: _keyCooldownUntil,
        value: until.millisecondsSinceEpoch.toString(),
      );
    }
    return next;
  }

  /// Reinicia el contador de intentos y elimina cualquier cooldown activo.
  /// Llamar siempre tras un desbloqueo exitoso.
  static Future<void> resetFailedAttempts() async {
    await _storage.delete(key: _keyFailedAttempts);
    await _storage.delete(key: _keyCooldownUntil);
  }

  /// Retorna el tiempo restante de cooldown, o null si no hay cooldown activo.
  /// Auto-limpia el almacenamiento si el cooldown ya expiró.
  static Future<Duration?> cooldownRemaining() async {
    final v = await _storage.read(key: _keyCooldownUntil);
    if (v == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) {
      // Cooldown expirado — auto-limpiar
      await resetFailedAttempts();
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
    await _storage.write(key: _keyUseBiometrics, value: enabled.toString());
  }

  /// true si el usuario tiene biometría habilitada como método de desbloqueo.
  static Future<bool> isBiometricsEnabled() async {
    final value = await _storage.read(key: _keyUseBiometrics);
    return value == 'true';
  }

  /// Lanza el prompt nativo de biometría.
  /// Retorna true si la autenticación fue exitosa.
  static Future<bool> authenticateWithBiometrics({
    String reason = 'Desbloquea tu aplicación COSSMIL',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  // ─── Nombre de usuario para pantalla de desbloqueo ────────────────────────

  /// Guarda el nombre de display del usuario autenticado.
  /// Llamar desde AuthService tras un login exitoso.
  static Future<void> saveDisplayName(String name) async {
    await _storage.write(key: _keyDisplayName, value: name);
  }

  /// Retorna el nombre guardado del usuario, o null si no existe.
  static Future<String?> getDisplayName() async {
    final v = await _storage.read(key: _keyDisplayName);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  // ─── Ventana de gracia al volver desde background ─────────────────────────

  /// Registra el momento exacto en que la app fue a background (paused).
  static Future<void> recordBackground() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _storage.write(key: _keyLastBackground, value: now.toString());
  }

  /// Retorna true si el tiempo en background superó la [graceWindowDuration].
  /// Si no hay timestamp guardado → asume que debe bloquear (primera vez o reinicio).
  /// Si ya está expirado → debe bloquear.
  static Future<bool> shouldLockOnResume() async {
    final v = await _storage.read(key: _keyLastBackground);
    if (v == null) return false; // No hay registro de background → no bloquear
    final backgroundAt = DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    final elapsed = DateTime.now().difference(backgroundAt);
    return elapsed > graceWindowDuration;
  }

  // ─── Bloqueo por inactividad ───────────────────────────────────────────────

  /// Actualiza el timestamp de última actividad real del usuario.
  static Future<void> recordActivity() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _storage.write(key: _keyLastActivity, value: now.toString());
  }

  /// Retorna true si el usuario lleva más de [inactivityTimeout] sin interactuar.
  static Future<bool> shouldLockOnInactivity() async {
    final hasPin = await SecurityService.hasPin();
    if (!hasPin) return false;
    final v = await _storage.read(key: _keyLastActivity);
    if (v == null) return false; // Sin registro → no bloquear
    final lastActivity = DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    final elapsed = DateTime.now().difference(lastActivity);
    return elapsed > inactivityTimeout;
  }

  // ─── Limpieza total ────────────────────────────────────────────────────────

  /// Elimina PIN, preferencia biométrica, datos de cooldown, nombre y timestamps.
  /// Se llama siempre al hacer logout.
  static Future<void> clearSecurityData() async {
    await _storage.delete(key: _keyPin);
    await _storage.delete(key: _keyUseBiometrics);
    await _storage.delete(key: _keyCooldownUntil);
    await _storage.delete(key: _keyFailedAttempts);
    await _storage.delete(key: _keyDisplayName);
    await _storage.delete(key: _keyLastBackground);
    await _storage.delete(key: _keyLastActivity);
  }
}
