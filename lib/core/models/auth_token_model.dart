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
  final int edad;
  final String rol;
  final String grado;
  final int idper;
  final String numeroCelular;
  final String correo;

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
    this.edad = 0,
    this.rol = '',
    this.grado = '',
    this.idper = 0,
    this.numeroCelular = '',
    this.correo = '',
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
      edad: val('edad') as int? ?? 0,
      rol: val('rol') as String? ?? '',
      grado: val('grado') as String? ?? '',
      idper: (val('idper') ?? int.tryParse(val('idusr')?.toString() ?? '')) as int? ?? 0,
      numeroCelular: val('numeroCelular') as String? ?? '',
      correo: val('correo') as String? ?? '',
    );
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
        'rol': rol,
        'grado': grado,
        'idper': idper,
        'numeroCelular': numeroCelular,
        'correo': correo,
      };
}
