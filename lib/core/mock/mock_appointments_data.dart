/// Datos mock de las últimas fichas/reservas médicas.
class MockAppointmentItem {
  final String id;
  final String patientName;
  final String specialty;
  final String doctorName;
  final String hospital;
  final String date;
  final String time;
  final String status;

  const MockAppointmentItem({
    required this.id,
    required this.patientName,
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
      patientName: 'Henry Alexander Pacheco Ventura',
      specialty: 'Medicina General',
      doctorName: 'Dr. Roberto Guzmán',
      hospital: 'Hospital Militar Central',
      date: '14 Mar 2026',
      time: '08:30',
      status: 'Confirmada',
    ),
    MockAppointmentItem(
      id: 'a2',
      patientName: 'Carolina Méndez de Pacheco',
      specialty: 'Ginecología',
      doctorName: 'Dra. Lucía Fernández',
      hospital: 'Hospital Militar Central',
      date: '12 Mar 2026',
      time: '10:00',
      status: 'Completada',
    ),
    MockAppointmentItem(
      id: 'a3',
      patientName: 'Mateo Pacheco Méndez',
      specialty: 'Pediatría',
      doctorName: 'Dr. Carlos Montaño',
      hospital: 'Policlínico Militar Miraflores',
      date: '10 Mar 2026',
      time: '14:15',
      status: 'Completada',
    ),
  ];
}
