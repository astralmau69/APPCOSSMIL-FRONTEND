import 'dart:convert';
import 'dart:typed_data';
import '../extensions/string_extensions.dart';

class DoctorModel {
  final String id;
  final String fullName;
  final String office;
  final String fecha;
  final String dia;
  final String foto;

  const DoctorModel({
    required this.id,
    required this.fullName,
    required this.office,
    this.fecha = '',
    this.dia = '',
    this.foto = '',
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: (json['idmed'] ?? json['id'] ?? '').toString(),
      fullName: (json['nombre_completo'] as String? ??
          json['fullName'] as String? ??
          '').toDisplayCase,
      office: (json['consultorio'] as String? ??
          json['office'] as String? ??
          '').toDisplayCase,
      fecha: json['fecha'] as String? ?? '',
      dia: json['dia'] as String? ?? '',
      foto: json['foto'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'office': office,
      };

  /// Returns "Dra." if the last word of fullName ends with 'A' and has ≥3 chars,
  /// otherwise returns "Dr.".
  String get prefix {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Dr.';
    final lastWord = trimmed.split(RegExp(r'\s+')).last.toUpperCase();
    if (lastWord.endsWith('A') && lastWord.length >= 3) return 'Dra.';
    return 'Dr.';
  }

  /// Full display name with the appropriate gender prefix.
  String get displayName => '$prefix $fullName';

  /// Convierte la foto a bytes de imagen.
  /// Soporta dos formatos:
  ///  - Base64 estándar
  ///  - Enteros con signo separados por coma (endpoint legacy)
  Uint8List? get photoBytes {
    if (foto.isEmpty) return null;
    // Detectar si es Base64: contiene '/', '+', '=' o solo alfanumérico sin comas
    if (!foto.contains(',')) {
      try {
        String normalized = foto.replaceAll('\n', '').replaceAll('\r', '');
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        return base64Decode(normalized);
      } catch (_) {
        return null;
      }
    }
    // Formato legacy: enteros con signo separados por coma
    try {
      final bytes = foto.split(',').map((s) {
        final v = int.parse(s.trim());
        return v < 0 ? v + 256 : v;
      }).toList();
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }
}
