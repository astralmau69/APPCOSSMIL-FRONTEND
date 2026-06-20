import 'dart:convert';
import 'package:crypto/crypto.dart';
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
  final String grado;
  final String tipoAsegurado;
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
    required this.grado,
    required this.tipoAsegurado,
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
      fuerza: _normalizeFuerza(u.fuerza),
      // Grado militar del titular (ej. "CORONEL"). El backend lo entrega en
      // `rank`; "Asegurado" es el valor por defecto cuando no hay grado.
      grado: (u.rank.trim().isNotEmpty && u.rank.trim().toLowerCase() != 'asegurado')
          ? u.rank.trim().toUpperCase()
          : '',
      tipoAsegurado: u.isTitular ? 'TITULAR' : 'BENEFICIARIO',
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
      // TODO(backend): la API móvil aún no entrega emisión/vencimiento.
      // Datos mock provisionales (vencimiento 2027) hasta conectar el servicio.
      fechaEmision: '01/05/2025',
      fechaVencimiento: '30/04/2027',
      atencion: 'ASEGURADO',
      codigo: u.id.trim(),
      photoBase64: u.photoBase64,
    );
  }

  /// Host de verificación de carnets COSSMIL.
  static const String verifyBaseUrl = 'https://www.cossmil.mil.bo/carnet/verificar';

  /// QR FIJO del carnet de seguro de salud (verificación en línea).
  ///
  /// Por ahora es un valor estático apuntando a la verificación COSSMIL.
  /// TODO(backend): reemplazar por el QR firmado que entregue el servicio de
  /// verificación, que se actualizará cada cierto tiempo (token rotativo).
  static const String fixedHealthQrPayload =
      '$verifyBaseUrl?src=app&v=1';

  // ─── QR ROTATIVO (hash que cambia cada 15 s) ──────────────────────────────

  /// Periodo de rotación del QR del carnet de seguro (segundos).
  static const int rotatingPeriodSeconds = 15;

  /// Secreto compartido para el hash rotativo (demo local). Cuando exista el
  /// servicio del backend, este hash se reemplaza por un token firmado por el
  /// servidor; mientras tanto, validador y carnet comparten este secreto.
  /// TODO(backend): mover a una clave entregada/validada por el servidor.
  static const String _rotatingSecret = 'COSSMIL-CARNET-ROT-v1';

  /// Ventana de tiempo actual (un número entero que avanza cada
  /// [rotatingPeriodSeconds] segundos). Es la base del hash rotativo.
  static int currentWindow([DateTime? now]) {
    final ms = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return (ms ~/ 1000) ~/ rotatingPeriodSeconds;
  }

  /// Segundos que faltan para que el QR cambie (para el contador en pantalla).
  static int secondsToNextWindow([DateTime? now]) {
    final s = ((now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000);
    return rotatingPeriodSeconds - (s % rotatingPeriodSeconds);
  }

  /// Hash rotativo (16 hex) de matrícula + código + ventana de tiempo. Cambia
  /// cada [rotatingPeriodSeconds] segundos.
  static String rotatingHash(String matricula, String codigo, int window) {
    final raw =
        '$_rotatingSecret|${matricula.trim().toUpperCase()}|${codigo.trim()}|$window';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 16);
  }

  /// Payload del QR rotativo: lleva matrícula, código, la ventana y su hash.
  /// Al escanearlo, el validador recalcula el hash de la ventana actual y
  /// confirma que coincide (carnet vigente y QR fresco).
  String rotatingQrPayload([DateTime? now]) {
    final win = currentWindow(now);
    final rh = rotatingHash(matricula, codigo, win);
    return '$verifyBaseUrl?mat=$matricula&cod=$codigo&w=$win&rh=$rh';
  }

  /// Valida un QR rotativo escaneado: `true` si el hash coincide con la ventana
  /// actual (o ±[tolerance] ventanas, para tolerar el desfase de reloj y el
  /// tiempo de escaneo). Funciona sin red usando el secreto compartido.
  static bool isRotatingValid(String raw, {DateTime? now, int tolerance = 1}) {
    try {
      final uri = Uri.parse(raw.trim());
      final mat = uri.queryParameters['mat'] ?? '';
      final cod = uri.queryParameters['cod'] ?? '';
      final rh = uri.queryParameters['rh'] ?? '';
      if (mat.isEmpty || cod.isEmpty || rh.isEmpty) return false;
      final cur = currentWindow(now);
      for (var d = -tolerance; d <= tolerance; d++) {
        if (rotatingHash(mat, cod, cur + d) == rh) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Hash de integridad (12 hex) sobre matrícula + código. Permite detectar si
  /// alguien alteró los parámetros del QR. NO es firma criptográfica (eso
  /// requiere clave del backend), pero sí valida que el QR no fue manipulado.
  static String integrityHash(String matricula, String codigo) {
    final raw = 'COSSMIL-CARNET|${matricula.trim().toUpperCase()}|${codigo.trim()}';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 12);
  }

  /// URL del QR: al escanearlo lleva a la verificación COSSMIL e incluye un
  /// hash de integridad de los datos del carnet.
  String get qrPayload =>
      '$verifyBaseUrl?mat=$matricula&cod=$codigo&h=${integrityHash(matricula, codigo)}';

  /// Parsea un QR de carnet COSSMIL. Retorna {matricula, codigo, hash} o null.
  static ({String matricula, String codigo, String hash})? parseQr(String raw) {
    try {
      final s = raw.trim();
      if (!s.toLowerCase().contains('cossmil')) return null;
      final uri = Uri.parse(s);
      final mat = uri.queryParameters['mat'] ?? '';
      final cod = uri.queryParameters['cod'] ?? '';
      final h = uri.queryParameters['h'] ?? '';
      if (mat.isEmpty || cod.isEmpty) return null;
      return (matricula: mat, codigo: cod, hash: h);
    } catch (_) {
      return null;
    }
  }

  /// `true` si el hash del QR coincide (no fue alterado).
  static bool isQrIntegrityValid(String matricula, String codigo, String hash) =>
      hash.isNotEmpty && hash == integrityHash(matricula, codigo);

  /// Normaliza la fuerza/rama institucional a su nombre legible.
  /// "EC" o "CIVIL" → "EMPLEADO CIVIL"; el resto se muestra en mayúsculas.
  static String _normalizeFuerza(String raw) {
    final f = raw.trim().toUpperCase();
    if (f.isEmpty) return '';
    if (f == 'EC' || f == 'CIVIL' || f.contains('EMPLEADO CIVIL')) {
      return 'EMPLEADO CIVIL';
    }
    return f;
  }

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
