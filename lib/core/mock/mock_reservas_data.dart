import '../models/reserva_model.dart';
import '../models/detalle_cita_model.dart';

/// Datos mock para el historial de citas y detalles.
class MockReservasData {
  static final List<ReservaModel> historial = [
    ReservaModel(
      id: '1',
      patientName: 'JORGE MAURICIO APARICIO QUISPE',
      relationship: 'Titular',
      specialty: 'NEUMOLOGIA',
      doctorName: 'CALLE VELA ELIAS',
      hospital: 'HOSPITAL MILITAR CENTRAL',
      date: '31 Mar 2026',
      time: '12:45',
      status: 'Pendiente',
      consultorio: 'CONSULTORIO 16 - PISO 1',
      codigoReserva: '2026-1-1-468-73324',
      gestion: 2026,
      idins: 1,
      idsuc: 1,
      idtran: 165,
      dr: 57501,
    ),
    ReservaModel(
      id: '2',
      patientName: 'JORGE MAURICIO APARICIO QUISPE',
      relationship: 'Titular',
      specialty: 'CARDIOLOGIA',
      doctorName: 'BUSTILLOS LOPEZ CARMEN TERESA',
      hospital: 'HOSPITAL MILITAR CENTRAL',
      date: '28 Mar 2026',
      time: '09:00',
      status: 'Completado',
      consultorio: 'CONSULTORIO 3 - PLANTA BAJA',
      codigoReserva: '2026-1-1-420-71500',
      gestion: 2026,
      idins: 1,
      idsuc: 1,
      idtran: 142,
      dr: 57501,
    ),
    ReservaModel(
      id: '3',
      patientName: 'MARIA ELENA QUISPE DE APARICIO',
      relationship: 'Esposa',
      specialty: 'GINECOLOGIA',
      doctorName: 'RODRIGUEZ FLORES PATRICIA',
      hospital: 'HOSPITAL MILITAR CENTRAL',
      date: '25 Mar 2026',
      time: '10:30',
      status: 'Completado',
      consultorio: 'CONSULTORIO 8 - 2DO PISO',
      codigoReserva: '2026-1-1-395-70200',
      gestion: 2026,
      idins: 1,
      idsuc: 1,
      idtran: 130,
      dr: 58200,
    ),
    ReservaModel(
      id: '4',
      patientName: 'JORGE MAURICIO APARICIO QUISPE',
      relationship: 'Titular',
      specialty: 'TRAUMATOLOGIA',
      doctorName: 'MENDOZA GUTIERREZ LUIS ALBERTO',
      hospital: 'HOSPITAL MILITAR CENTRAL',
      date: '20 Mar 2026',
      time: '08:15',
      status: 'Completado',
      consultorio: 'CONSULTORIO 12 - 1ER PISO',
      codigoReserva: '2026-1-1-380-69100',
      gestion: 2026,
      idins: 1,
      idsuc: 1,
      idtran: 118,
      dr: 57501,
    ),
    ReservaModel(
      id: '5',
      patientName: 'DIEGO APARICIO QUISPE',
      relationship: 'Hijo',
      specialty: 'PEDIATRIA',
      doctorName: 'VARGAS SOLIZ ANDREA',
      hospital: 'HOSPITAL MILITAR CENTRAL',
      date: '15 Mar 2026',
      time: '14:00',
      status: 'Falta',
      consultorio: 'CONSULTORIO 5 - PLANTA BAJA',
      codigoReserva: '2026-1-1-350-67800',
      gestion: 2026,
      idins: 1,
      idsuc: 1,
      idtran: 105,
      dr: 59100,
    ),
    ReservaModel(
      id: '6',
      patientName: 'JORGE MAURICIO APARICIO QUISPE',
      relationship: 'Titular',
      specialty: 'MEDICINA GENERAL',
      doctorName: 'VILLAGOMEZ POSTIGO MARIANELA',
      hospital: 'HOSPITAL MILITAR CENTRAL',
      date: '10 Mar 2026',
      time: '11:15',
      status: 'Completado',
      consultorio: 'CONSULTORIO 2 - PLANTA BAJA',
      codigoReserva: '2026-1-1-310-65400',
      gestion: 2026,
      idins: 1,
      idsuc: 1,
      idtran: 92,
      dr: 57501,
    ),
    ReservaModel(
      id: '7',
      patientName: 'MARIA ELENA QUISPE DE APARICIO',
      relationship: 'Esposa',
      specialty: 'OFTALMOLOGIA',
      doctorName: 'PACO TORREZ ROBERTO',
      hospital: 'HOSPITAL MILITAR CENTRAL',
      date: '05 Mar 2026',
      time: '15:30',
      status: 'Completado',
      consultorio: 'CONSULTORIO 20 - 2DO PISO',
      codigoReserva: '2026-1-1-285-63200',
      gestion: 2026,
      idins: 1,
      idsuc: 1,
      idtran: 78,
      dr: 58200,
    ),
  ];

  /// Genera un DetalleCitaModel mock basado en una reserva.
  static DetalleCitaModel detalleFromReserva(ReservaModel r) {
    // Map status a estados del backend
    String estadoConfirmacion;
    String estadoAtencion;

    switch (r.status.toLowerCase()) {
      case 'pendiente':
        estadoConfirmacion = 'POR CONFIRMAR';
        estadoAtencion = 'PENDIENTE';
      case 'completado':
        estadoConfirmacion = 'CONFIRMADO';
        estadoAtencion = 'ATENDIDO';
      case 'falta':
        estadoConfirmacion = 'CONFIRMADO';
        estadoAtencion = 'NO ASISTIO';
      default:
        estadoConfirmacion = 'POR CONFIRMAR';
        estadoAtencion = 'PENDIENTE';
    }

    // Convertir fecha "31 Mar 2026" a "2026-03-31"
    final fechaIso = _parseDateToIso(r.date);

    return DetalleCitaModel(
      gestion: r.gestion ?? 2026,
      idins: r.idins ?? 1,
      idsuc: r.idsuc ?? 1,
      idtran: r.idtran ?? 0,
      dr: r.dr ?? 0,
      matricula: '010325AQJ',
      especialidad: r.specialty,
      consultorio: r.consultorio ?? '',
      abrcons: _abrConsultorio(r.consultorio ?? ''),
      fechaCita: fechaIso,
      horaCita: r.time,
      numero: (r.idtran ?? 0) % 12 + 1,
      medico: r.doctorName,
      obs: 'AUTOSERVICIO',
      sucursal: r.hospital,
      codadm: r.codigoReserva ?? '',
      paciente: r.patientName,
      estadoConfirmacion: estadoConfirmacion,
      estadoAtencion: estadoAtencion,
      fechaCreacion: '${fechaIso}T08:30:00.000',
    );
  }

  static String _parseDateToIso(String date) {
    const months = {
      'Ene': '01', 'Feb': '02', 'Mar': '03', 'Abr': '04',
      'May': '05', 'Jun': '06', 'Jul': '07', 'Ago': '08',
      'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dic': '12',
    };
    final parts = date.split(' ');
    if (parts.length == 3) {
      final day = parts[0].padLeft(2, '0');
      final month = months[parts[1]] ?? '01';
      final year = parts[2];
      return '$year-$month-$day';
    }
    return '2026-03-31';
  }

  static String _abrConsultorio(String full) {
    // "CONSULTORIO 16 - PISO 1" → "P1-16"
    final match = RegExp(r'CONSULTORIO\s+(\d+).*?(?:PISO|PLANTA)\s+(\w+)', caseSensitive: false).firstMatch(full);
    if (match != null) {
      final num = match.group(1)!;
      final piso = match.group(2)!;
      final pisoLabel = piso.toUpperCase() == 'BAJA' ? 'PB' : 'P$piso';
      return '$pisoLabel-$num';
    }
    return '';
  }
}
