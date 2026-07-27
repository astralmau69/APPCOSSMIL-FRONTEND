import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

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

  /// Cédula de identidad. El backend no siempre la envía para beneficiarios;
  /// cuando falta queda vacía y los formularios la dejan editable.
  final String ci;
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
    this.ci = '',
    this.matricula = '',
    this.photoBase64 = '',
    this.age,
    this.gender = '',
    this.grado = '',
    this.serviceStatus = '',
    this.atencion = 'S',
  });

  /// Diagnóstico único por sesión: qué claves envía realmente el backend
  /// (para detectar bajo qué nombre viene la cédula de identidad).
  static bool _loggedKeys = false;

  factory BeneficiaryModel.fromJson(Map<String, dynamic> json) {
    if (kDebugMode && !_loggedKeys) {
      _loggedKeys = true;
      debugPrint('🪪 beneficiario: claves del backend = ${json.keys.toList()}');
    }
    // Construir nombre completo desde pat/mat/nom si no viene directo
    String fullName =
        (json['nombre_completo'] as String? ??
                json['fullName'] as String? ??
                '')
            .trim();
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
      relationship:
          (json['parentesco'] as String? ??
                  json['relationship'] as String? ??
                  '')
              .trim()
              .toDisplayCase,
      ci:
          (json['ci'] ??
                  json['docide'] ??
                  json['cedula'] ??
                  json['nrodoc'] ??
                  json['numdoc'] ??
                  '')
              .toString()
              .trim(),
      matricula:
          (json['mtrben'] ??
                  json['matricula'] ??
                  json['nromatricula'] ??
                  json['nromat'] ??
                  json['codigo'] ??
                  '')
              .toString()
              .trim(),
      photoBase64:
          (json['foto'] as String? ??
                  json['foto2'] as String? ??
                  json['foto_base64'] as String? ??
                  '')
              .trim(),
      age: json['edad'] as int? ?? json['age'] as int?,
      gender:
          (json['sexo'] as String? ??
                  json['genero'] as String? ??
                  json['gender'] as String? ??
                  '')
              .trim(),
      grado: (json['grado'] as String? ?? '').trim(),
      serviceStatus:
          json['serviceStatus'] as String? ?? json['refe4'] as String? ?? '',
      atencion: (json['atencion'] as String? ?? 'S').trim().toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'relationship': relationship,
    'ci': ci,
    'matricula': matricula,
    'photoBase64': photoBase64,
    'age': age,
    'gender': gender,
    'grado': grado,
    'serviceStatus': serviceStatus,
    'atencion': atencion,
  };

  /// Reconstruye desde [toJson] para la caché offline, SIN re-normalizar y
  /// leyendo `photoBase64` tal cual (a diferencia de [fromJson], que espera las
  /// claves crudas del backend `foto`/`nombre_completo` y perdería el retrato en
  /// un round-trip). Úsese solo para leer la caché cifrada del grupo familiar.
  factory BeneficiaryModel.fromCacheMap(Map<String, dynamic> m) =>
      BeneficiaryModel(
        id: m['id'] as String? ?? '',
        fullName: m['fullName'] as String? ?? '',
        relationship: m['relationship'] as String? ?? '',
        ci: m['ci'] as String? ?? '',
        matricula: m['matricula'] as String? ?? '',
        photoBase64: m['photoBase64'] as String? ?? '',
        age: m['age'] as int?,
        gender: m['gender'] as String? ?? '',
        grado: m['grado'] as String? ?? '',
        serviceStatus: m['serviceStatus'] as String? ?? '',
        atencion: m['atencion'] as String? ?? 'S',
      );

  /// First letter of name for avatar display.
  String get initial => fullName.isNotEmpty ? fullName[0] : '?';

  /// Whether this beneficiary is the account holder.
  bool get isTitular => relationship.toUpperCase() == 'TITULAR';

  /// Nombre con tratamiento apropiado:
  /// - **Titular**: grado militar como prefijo si lo tiene (ej. "Cnl. Juan Pérez"),
  ///   o solo nombre si es civil / sin grado.
  /// - **Beneficiario**: "Sr." / "Sra." según edad y género (niños sin prefijo).
  String get displayTitle => RankUtils.displayNameWithPrefix(
    fullName: fullName,
    isTitular: isTitular,
    grado: isTitular ? effectiveGrado : '',
    age: age,
    gender: effectiveGender,
  );

  /// Etiqueta de estado de servicio.
  String get serviceLabel => RankUtils.serviceStatusLabel(serviceStatus);

  /// `true` si el servicio es activo.
  bool get isServiceActive => RankUtils.isServiceActive(serviceStatus);

  /// `true` si el beneficiario está habilitado para atención médica (atencion == "S").
  bool get isAtencionEnabled => atencion != 'N';

  /// Grado efectivo para lógica interna (valor crudo del backend).
  ///
  /// - **Titular**: usa `grado` del campo propio; si está vacío, usa `_titularRankFallback`.
  /// - **Beneficiario**: retorna `grado` tal como lo envió el backend.
  ///   Si el beneficiario no tiene grado propio (caso habitual), será vacío.
  ///   Si el backend le asignó uno (ej. esposo/a militar), se conserva.
  ///   Nunca se hereda el grado del titular.
  String get effectiveGrado {
    if (isTitular) {
      if (grado.isNotEmpty) return grado;
      return _titularRankFallback;
    }
    // Beneficiario: solo su grado propio (sin herencia del titular)
    return grado;
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
    if (rel.contains('ESPOSA') || rel.contains('HIJA') || rel.contains('MADRE'))
      return 'FEMENINO';
    if (rel.contains('ESPOSO') || rel.contains('HIJO') || rel.contains('PADRE'))
      return 'MASCULINO';
    return '';
  }

  /// Género con primera letra en mayúscula, para mostrar en UI.
  /// Mantiene [effectiveGender] en ALLCAPS para comparaciones internas.
  String get displayGender => effectiveGender.toDisplayCase;
}
