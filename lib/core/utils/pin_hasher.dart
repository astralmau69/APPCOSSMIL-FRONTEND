import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Hash + salt de un PIN, en Base64. Pensado para persistir sin exponer el PIN.
class PinHash {
  final String hash; // PBKDF2 derivado, Base64
  final String salt; // salt aleatorio, Base64

  const PinHash({required this.hash, required this.salt});
}

/// Derivación de claves PIN con PBKDF2-HMAC-SHA256 (mismo esquema que
/// [SecurityService]). Se extrae a un helper para poder reutilizarlo en el
/// almacenamiento multi-cuenta sin duplicar la criptografía.
class PinHasher {
  PinHasher._();

  static const int _iterations = 10000;
  static const int _keyLength = 32;

  static Uint8List _pbkdf2(String password, Uint8List salt) {
    final mac = Hmac(sha256, utf8.encode(password));
    final numBlocks = (_keyLength + 31) ~/ 32;
    final result = BytesBuilder();

    for (int i = 1; i <= numBlocks; i++) {
      final blockIndexBytes = ByteData(4)..setInt32(0, i, Endian.big);
      final saltWithBlockIndex = Uint8List(salt.length + 4)
        ..setAll(0, salt)
        ..setAll(salt.length, blockIndexBytes.buffer.asUint8List());

      var u = mac.convert(saltWithBlockIndex).bytes;
      final t = Uint8List.fromList(u);

      for (int j = 2; j <= _iterations; j++) {
        u = mac.convert(u).bytes;
        for (int k = 0; k < 32; k++) {
          t[k] ^= u[k];
        }
      }
      result.add(t);
    }

    return result.toBytes().sublist(0, _keyLength);
  }

  static Uint8List _secureSalt([int length = 16]) {
    final random = Random.secure();
    final salt = Uint8List(length);
    for (int i = 0; i < length; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  /// Genera hash + salt para un PIN nuevo.
  static PinHash hash(String pin) {
    final salt = _secureSalt();
    final derived = _pbkdf2(pin, salt);
    return PinHash(hash: base64.encode(derived), salt: base64.encode(salt));
  }

  /// Verifica un PIN contra su hash+salt guardados.
  static bool verify(String pin, String hashB64, String saltB64) {
    if (hashB64.isEmpty || saltB64.isEmpty) return false;
    try {
      final salt = base64.decode(saltB64);
      final derived = _pbkdf2(pin, salt);
      return base64.encode(derived) == hashB64;
    } catch (_) {
      return false;
    }
  }
}
