/// Modelo que representa la respuesta del servidor al hacer login.
/// Mapea el JSON del endpoint OAuth2.
class AuthTokenModel {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String scope;
  final String jti;

  const AuthTokenModel({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.scope,
    required this.jti,
  });

  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    return AuthTokenModel(
      accessToken: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 0,
      scope: json['scope'] as String? ?? '',
      jti: json['jti'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
        'scope': scope,
        'jti': jti,
      };
}
