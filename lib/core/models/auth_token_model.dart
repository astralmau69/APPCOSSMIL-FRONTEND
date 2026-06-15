import 'dart:convert';

/// Modelo que representa la respuesta del servidor al hacer login.
/// Mapea el JSON del endpoint OAuth2.
class AuthTokenModel {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final String scope;
  final String jti;

  // Extra user fields from token JSON
  final String mat;
  final String pat;
  final String nom;
  final String ci;
  final String matricula;
  /// Matrícula del titular del seguro (campo `mtrtit` del token). Para
  /// beneficiarios apunta al titular; para titulares suele ser su propia matrícula.
  final String mtrtit;
  final int edad;
  final String genero;
  final String rol;
  final String grado;
  final int idper;
  final String numeroCelular;
  final String correo;
  final int? idseg;
  final String? uc;
  final String bloodType;
  final String allergies;
  /// `false` = debe cambiar contraseña (primer ingreso), `true` = ya cambió.
  final bool reqReset;

  const AuthTokenModel({
    required this.accessToken,
    this.refreshToken = '',
    required this.tokenType,
    required this.expiresIn,
    required this.scope,
    required this.jti,
    this.mat = '',
    this.pat = '',
    this.nom = '',
    this.ci = '',
    this.matricula = '',
    this.mtrtit = '',
    this.edad = 0,
    this.genero = '',
    this.rol = '',
    this.grado = '',
    this.idper = 0,
    this.numeroCelular = '',
    this.correo = '',
    this.idseg,
    this.uc,
    this.bloodType = '',
    this.allergies = '',
    this.reqReset = true,
  });

  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    final accessToken = (json['access_token'] as String? ?? '').trim();
    final refreshToken = (json['refresh_token'] as String? ?? '').trim();
    
    // Decodificar payload secundario del token JWT por si el response raíz no incluye estos datos
    Map<String, dynamic> payload = {};
    if (accessToken.split('.').length == 3) {
      try {
        final payloadBase64 = accessToken.split('.')[1];
        String normalized = payloadBase64.replaceAll('-', '+').replaceAll('_', '/');
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        final payloadStr = utf8.decode(base64Decode(normalized));
        payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      } catch (e) {
        // Fallback silencioso
      }
    }

    // Función auxiliar para buscar en payload del JWT primero, luego en root json
    dynamic val(String key) => payload[key] ?? json[key];

    return AuthTokenModel(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: json['token_type'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 0,
      scope: json['scope'] as String? ?? '',
      jti: val('jti') as String? ?? '',
      mat: val('mat') as String? ?? '',
      pat: val('pat') as String? ?? '',
      nom: val('nom') as String? ?? '',
      ci: val('ci') as String? ?? '',
      matricula: val('matricula') as String? ?? '',
      mtrtit: val('mtrtit') as String? ?? val('matriculaTit') as String? ?? '',
      edad: val('edad') as int? ?? 0,
      genero: val('genero') as String? ?? val('sexo') as String? ?? val('gender') as String? ?? '',
      rol: val('rol') as String? ?? '',
      grado: val('grado') as String? ?? '',
      idper: (val('idper') ?? int.tryParse(val('idusr')?.toString() ?? '')) as int? ?? 0,
      numeroCelular: val('numeroCelular') as String? ?? '',
      correo: val('correo') as String? ?? '',
      idseg: val('idseg') as int?,
      uc: val('uc')?.toString(),
      bloodType: val('grupoSanguineo') as String? ?? val('grupo_sanguineo') as String? ?? val('bloodType') as String? ?? '',
      allergies: val('alergias') as String? ?? val('allergies') as String? ?? '',
      reqReset: _parseBool(val('req_reset')),
    );
  }

  /// Parsea `req_reset` que puede venir como bool o int desde el backend.
  /// `false` / `0` = debe cambiar contraseña; `true` / `1` = ya cambió.
  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    return true; // default: ya cambió (no forzar)
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
        'scope': scope,
        'jti': jti,
        'mat': mat,
        'pat': pat,
        'nom': nom,
        'ci': ci,
        'matricula': matricula,
        'edad': edad,
        'genero': genero,
        'rol': rol,
        'grado': grado,
        'idper': idper,
        'numeroCelular': numeroCelular,
        'correo': correo,
      };
}
