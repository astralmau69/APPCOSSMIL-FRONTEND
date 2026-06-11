/// Una cuenta guardada localmente para el login rápido multi-cuenta
/// (estilo "elegir cuenta" de Facebook).
///
/// NO contiene la contraseña: esa se guarda por separado en almacenamiento
/// seguro bajo una clave propia (ver [AccountsStore]). Aquí solo viven los
/// datos para pintar la "cajita" y el PIN por cuenta (hash + salt).
class SavedAccount {
  /// Matrícula = usuario de login. Sirve de identificador único.
  final String matricula;

  /// Nombre a mostrar en la tarjeta.
  final String displayName;

  /// Foto del titular (Base64) para el avatar de la tarjeta. Puede estar vacía.
  final String photoBase64;

  /// Hash PBKDF2 del PIN de 4 dígitos de ESTA cuenta (Base64).
  final String pinHash;

  /// Salt del PIN de ESTA cuenta (Base64).
  final String pinSalt;

  /// Si el usuario habilitó huella para desbloquear esta cuenta.
  final bool biometricEnabled;

  /// Timestamp del último uso (ms) — para ordenar las tarjetas (reciente primero).
  final int lastUsedMs;

  const SavedAccount({
    required this.matricula,
    required this.displayName,
    this.photoBase64 = '',
    required this.pinHash,
    required this.pinSalt,
    this.biometricEnabled = false,
    this.lastUsedMs = 0,
  });

  /// Clave normalizada para comparar matrículas sin importar espacios/mayúsculas.
  String get key => matricula.trim().toUpperCase();

  SavedAccount copyWith({
    String? matricula,
    String? displayName,
    String? photoBase64,
    String? pinHash,
    String? pinSalt,
    bool? biometricEnabled,
    int? lastUsedMs,
  }) {
    return SavedAccount(
      matricula: matricula ?? this.matricula,
      displayName: displayName ?? this.displayName,
      photoBase64: photoBase64 ?? this.photoBase64,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      lastUsedMs: lastUsedMs ?? this.lastUsedMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'matricula': matricula,
        'displayName': displayName,
        'photoBase64': photoBase64,
        'pinHash': pinHash,
        'pinSalt': pinSalt,
        'biometricEnabled': biometricEnabled,
        'lastUsedMs': lastUsedMs,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        matricula: json['matricula'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        photoBase64: json['photoBase64'] as String? ?? '',
        pinHash: json['pinHash'] as String? ?? '',
        pinSalt: json['pinSalt'] as String? ?? '',
        biometricEnabled: json['biometricEnabled'] as bool? ?? false,
        lastUsedMs: json['lastUsedMs'] as int? ?? 0,
      );
}
