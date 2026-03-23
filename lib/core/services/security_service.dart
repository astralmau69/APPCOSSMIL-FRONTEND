import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Servicio para gestionar la seguridad local (PIN y Biometría).
class SecurityService {
  static const _storage = FlutterSecureStorage();
  static final _localAuth = LocalAuthentication();

  static const _keyPin = 'local_pin';
  static const _keyUseBiometrics = 'use_biometrics';

  /// Verifica si el usuario ha configurado un PIN.
  static Future<bool> hasPin() async {
    final pin = await _storage.read(key: _keyPin);
    return pin != null && pin.isNotEmpty;
  }

  /// Guarda un nuevo PIN de 4 dígitos.
  static Future<void> savePin(String pin) async {
    if (pin.length != 4) throw Exception('El PIN debe tener 4 dígitos');
    await _storage.write(key: _keyPin, value: pin);
  }

  /// Verifica si el PIN ingresado es correcto.
  static Future<bool> verifyPin(String pin) async {
    final savedPin = await _storage.read(key: _keyPin);
    return savedPin == pin;
  }

  /// Verifica si el dispositivo soporta biometría.
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Obtiene la lista de biometrías disponibles.
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  /// Activa o desactiva el uso de biometría.
  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _keyUseBiometrics, value: enabled.toString());
  }

  /// Verifica si el usuario ha activado la biometría.
  static Future<bool> isBiometricsEnabled() async {
    final value = await _storage.read(key: _keyUseBiometrics);
    return value == 'true';
  }

  /// Intenta autenticar con biometría.
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

  /// Borra toda la configuración de seguridad local.
  static Future<void> clearSecurityData() async {
    await _storage.delete(key: _keyPin);
    await _storage.delete(key: _keyUseBiometrics);
  }
}
