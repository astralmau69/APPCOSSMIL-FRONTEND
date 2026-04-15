import '../extensions/string_extensions.dart';
import '../utils/rank_utils.dart';

/// Rango del titular actual, seteado externamente por AuthService/SessionRestore.
/// Usado como fallback cuando el beneficiario titular no tiene su propio grado.
String _titularRankFallback = '';

class BeneficiaryModel {
  /// Permite a auth_service/session_restore setear el rango del titular como fallback.
  static set titularRankFallback(String rank) => _titularRankFallback = rank;
  final String id;
  final String fullName;
  final String relationship;
  final String matricula;
  final String photoBase64;
  final int? age;
  final String gender;
  /// Rango militar (solo relevante para titulares). Ej: "CORONEL"
  final String grado;
  /// Estado de servicio del endpoint de foto (refe4). Ej: "ACTIVO"
  final String serviceStatus;
  /// Habilitación para atención médica. "S" = habilitado, "N" = deshabilitado.
  final String atencion;

  const BeneficiaryModel({
    required this.id,
    required this.fullName,
    required this.relationship,
    this.matricula = '',
    this.photoBase64 = '',
    this.age,
    this.gender = '',
    this.grado = '',
    this.serviceStatus = '',
    this.atencion = 'S',
  });

  factory BeneficiaryModel.fromJson(Map<String, dynamic> json) {
    // Construir nombre completo desde pat/mat/nom si no viene directo
    String fullName = (json['nombre_completo'] as String? ??
        json['fullName'] as String? ??
        '').trim();
    if (fullName.isEmpty) {
      final pat = (json['pat'] as String? ?? '').trim();
      final mat = (json['mat'] as String? ?? '').trim();
      final nom = (json['nom'] as String? ?? '').trim();
      if (nom.isNotEmpty || pat.isNotEmpty || mat.isNotEmpty) {
        fullName = [nom, pat, mat].where((s) => s.isNotEmpty).join(' ');
      }
    }

    return BeneficiaryModel(
      id: (json['idper'] ?? json['idben'] ?? json['id'] ?? '').toString(),
      fullName: fullName.toDisplayCase,
      relationship: (json['parentesco'] as String? ??
          json['relationship'] as String? ??
          '').trim().toDisplayCase,
      matricula: (json['mtrben'] ??
                  json['matricula'] ??
                  json['nromatricula'] ??
                  json['nromat'] ??
                  json['codigo'] ??
                  '').toString().trim(),
      photoBase64: (json['foto'] as String? ??
                   json['foto2'] as String? ??
                   json['foto_base64'] as String? ??
                   '').trim(),
      age: json['edad'] as int? ?? json['age'] as int?,
      gender: (json['sexo'] as String? ??
              json['genero'] as String? ??
              json['gender'] as String? ??
              '').trim(),
      grado: (json['grado'] as String? ?? '').trim(),
      serviceStatus: json['serviceStatus'] as String? ?? json['refe4'] as String? ?? '',
      atencion: (json['atencion'] as String? ?? 'S').trim().toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'relationship': relationship,
        'matricula': matricula,
        'photoBase64': photoBase64,
        'age': age,
        'gender': gender,
        'grado': grado,
        'serviceStatus': serviceStatus,
        'atencion': atencion,
      };

  /// First letter of name for avatar display.
  String get initial => fullName.isNotEmpty ? fullName[0] : '?';

  /// Whether this beneficiary is the account holder.
  bool get isTitular => relationship.toUpperCase() == 'TITULAR';

  /// Nombre con prefijo de rango (titular) o tratamiento (beneficiario).
  String get displayTitle {
    // Para titulares, si grado está vacío, usar el fallback global
    String effectiveGrado = grado;
    if (isTitular && effectiveGrado.isEmpty && _titularRankFallback.isNotEmpty) {
      effectiveGrado = _titularRankFallback;
    }
    return RankUtils.displayNameWithPrefix(
      fullName: fullName,
      isTitular: isTitular,
      grado: effectiveGrado,
      age: age,
      gender: effectiveGender,
    );
  }

  /// Etiqueta de estado de servicio.
  String get serviceLabel => RankUtils.serviceStatusLabel(serviceStatus);

  /// `true` si el servicio es activo.
  bool get isServiceActive => RankUtils.isServiceActive(serviceStatus);

  /// `true` si el beneficiario está habilitado para atención médica (atencion == "S").
  bool get isAtencionEnabled => atencion != 'N';

  /// Grado efectivo para lógica interna (valor crudo del backend).
  /// - Titulares: usa `grado` del campo propio; si está vacío, usa `_titularRankFallback`.
  /// - Beneficiarios: siempre vacío (no tienen rango militar propio).
  String get effectiveGrado {
    if (!isTitular) return '';
    if (grado.isNotEmpty) return grado;
    return _titularRankFallback;
  }

  /// Grado con primera letra en mayúscula por palabra, para mostrar en UI.
  String get displayGrado => effectiveGrado.toDisplayCase;

  /// Infiere género a partir del parentesco si no viene explícito del backend.
  ///
  /// Útil cuando el backend no envía `genero` para beneficiarios pero sí
  /// envía `parentesco` (Esposa, Hija, Hijo, etc.).
  String get effectiveGender {
    if (gender.isNotEmpty) return gender.toUpperCase();
    final rel = relationship.toUpperCase();
    if (rel.contains('ESPOSA') || rel.contains('HIJA') || rel.contains('MADRE')) return 'FEMENINO';
    if (rel.contains('ESPOSO') || rel.contains('HIJO') || rel.contains('PADRE')) return 'MASCULINO';
    return '';
  }

  /// Género con primera letra en mayúscula, para mostrar en UI.
  /// Mantiene [effectiveGender] en ALLCAPS para comparaciones internas.
  String get displayGender => effectiveGender.toDisplayCase;
}
