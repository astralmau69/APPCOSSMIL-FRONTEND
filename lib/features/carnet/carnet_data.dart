import 'package:intl/intl.dart';
import '../../core/models/user_model.dart';

/// Datos del carnet de asegurado COSSMIL, mapeados desde el [UserModel] del
/// dueño de la cuenta. Los campos que el backend aún no entrega quedan vacíos
/// (se muestran como "—" en la UI).
class CarnetData {
  final String matricula;
  final String ci;
  final String nombreCompleto;
  final String fuerza;
  final String fechaNacimiento;
  final String matriculaTitular;
  final String estadoCivil;
  final String grupoSanguineo;
  final String alergias;
  final String telefonoReferencia;
  final String fechaEmision;
  final String fechaVencimiento;
  final String atencion;
  final String codigo;
  final String photoBase64;

  const CarnetData({
    required this.matricula,
    required this.ci,
    required this.nombreCompleto,
    required this.fuerza,
    required this.fechaNacimiento,
    required this.matriculaTitular,
    required this.estadoCivil,
    required this.grupoSanguineo,
    required this.alergias,
    required this.telefonoReferencia,
    required this.fechaEmision,
    required this.fechaVencimiento,
    required this.atencion,
    required this.codigo,
    required this.photoBase64,
  });

  factory CarnetData.fromUser(UserModel u) {
    return CarnetData(
      matricula: u.matricula.trim(),
      ci: u.ci.trim(),
      nombreCompleto: u.fullName.trim(),
      fuerza: u.fuerza.trim().isNotEmpty ? u.fuerza.trim().toUpperCase() : '',
      fechaNacimiento: _formatDate(u.birthDate),
      matriculaTitular: u.matriculaTitular.trim(),
      // Estado civil aún no lo expone la API móvil.
      estadoCivil: '',
      grupoSanguineo: u.bloodType.trim(),
      alergias: u.allergies.trim(),
      // "Telf. de referencia" del carnet = celular del afiliado.
      telefonoReferencia: u.numCel.trim().isNotEmpty
          ? u.numCel.trim()
          : (u.phone.trim().isNotEmpty ? u.phone.trim() : u.emergencyPhone.trim()),
      fechaEmision: '',
      fechaVencimiento: '',
      atencion: 'ASEGURADO',
      codigo: u.id.trim(),
      photoBase64: u.photoBase64,
    );
  }

  /// Contenido del QR de verificación del carnet.
  String get qrPayload =>
      'https://www.cossmil.mil.bo/carnet/$matricula?cod=$codigo';

  /// Devuelve el valor o "—" si está vacío (para campos aún no provistos).
  static String orDash(String v) => v.trim().isEmpty ? '—' : v.trim();

  /// Normaliza una fecha a dd-MM-yyyy si es parseable; si no, la deja igual.
  static String _formatDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    // Intentar varios formatos comunes del backend.
    for (final fmt in ['yyyy-MM-dd', 'dd/MM/yyyy', 'yyyy/MM/dd', 'dd-MM-yyyy']) {
      try {
        final dt = DateFormat(fmt).parseStrict(s.split('T').first);
        return DateFormat('dd-MM-yyyy').format(dt);
      } catch (_) {}
    }
    return s;
  }
}
