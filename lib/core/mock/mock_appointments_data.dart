/// Datos mock de las últimas fichas/reservas médicas.
class MockAppointmentItem {
  final String id;
  final String patientName;
  final String relationship; // 'Titular' o 'Beneficiario'
  final String specialty;
  final String doctorName;
  final String hospital;
  final String date;
  final String time;
  final String status;

  const MockAppointmentItem({
    required this.id,
    required this.patientName,
    required this.relationship,
    required this.specialty,
    required this.doctorName,
    required this.hospital,
    required this.date,
    required this.time,
    required this.status,
  });
}

class MockAppointmentsData {
  static const List<MockAppointmentItem> recentAppointments = [
    MockAppointmentItem(
      id: 'a1',
      patientName: 'Javier Arispe Mendez',
      relationship: 'Titular',
      specialty: 'Medicina General',
      doctorName: 'Dr. Roberto Guzmán',
      hospital: 'Hospital Militar Central',
      date: '14 Mar 2026',
      time: '08:30',
      status: 'Completada',
    ),
    MockAppointmentItem(
      id: 'a2',
      patientName: 'Carolina Méndez',
      relationship: 'Esposa (Beneficiaria)',
      specialty: 'Ginecología',
      doctorName: 'Dra. Lucía Fernández',
      hospital: 'Hospital Militar Central',
      date: '12 Mar 2026',
      time: '10:00',
      status: 'Completada',
    ),
    MockAppointmentItem(
      id: 'a3',
      patientName: 'Mateo Arispe',
      relationship: 'Hijo (Beneficiario)',
      specialty: 'Pediatría',
      doctorName: 'Dr. Carlos Montaño',
      hospital: 'Policlínico Miraflores',
      date: '10 Mar 2026',
      time: '14:15',
      status: 'Completada',
    ),
    MockAppointmentItem(
      id: 'a4',
      patientName: 'Javier Arispe Mendez',
      relationship: 'Titular',
      specialty: 'Odontología',
      doctorName: 'Dra. Paola Suarez',
      hospital: 'COSSMIL Cochabamba',
      date: '02 Mar 2026',
      time: '11:00',
      status: 'Completada',
    ),
    MockAppointmentItem(
      id: 'a5',
      patientName: 'Valeria Arispe',
      relationship: 'Hija (Beneficiaria)',
      specialty: 'Pediatría',
      doctorName: 'Dr. Carlos Montaño',
      hospital: 'Policlínico Miraflores',
      date: '25 Feb 2026',
      time: '09:30',
      status: 'Completada',
    ),
  ];
}
