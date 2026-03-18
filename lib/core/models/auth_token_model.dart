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
  final int idper;

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
    this.idper = 0,
  });

  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    return AuthTokenModel(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 0,
      scope: json['scope'] as String? ?? '',
      jti: json['jti'] as String? ?? '',
      mat: json['mat'] as String? ?? '',
      pat: json['pat'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      ci: json['ci'] as String? ?? '',
      matricula: json['matricula'] as String? ?? '',
      edad: json['edad'] as int? ?? 0,
      rol: json['rol'] as String? ?? '',
      idper: json['idper'] as int? ?? 0,
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
        'idper': idper,
      };
}
