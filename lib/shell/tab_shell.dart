import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/models/beneficiary_model.dart';
import '../core/models/regional_model.dart';
import '../core/models/hospital_model.dart';
import '../core/models/specialty_model.dart';
import '../core/models/doctor_model.dart';
import '../features/home/screens/home_screen.dart';
import '../features/reservas/screens/reservas_screen.dart';
import '../features/booking/screens/regional_screen.dart';
import '../features/familia/screens/familia_screen.dart';
import '../features/perfil/screens/perfil_screen.dart';

/// Estado mutable del flujo de reserva, compartido entre pantallas.
class BookingState {
  String? beneficiaryLabel;
  BeneficiaryModel? beneficiary;
  RegionalModel? regional;
  HospitalModel? hospital;
  SpecialtyModel? specialty;
  DoctorModel? doctor;
  String? selectedTime;

  void reset() {
    beneficiaryLabel = null;
    beneficiary = null;
    regional = null;
    hospital = null;
    specialty = null;
    doctor = null;
    selectedTime = null;
  }
}

class TabShell extends StatefulWidget {
  const TabShell({super.key});

  @override
  State<TabShell> createState() => TabShellState();
}

class TabShellState extends State<TabShell> {
  int _currentIndex = 0;
  final bookingState = BookingState();

  UniqueKey _bookingNavKey = UniqueKey();

  /// Llamado desde HomeScreen al seleccionar un beneficiario.
  void startBooking(String label, BeneficiaryModel? beneficiary) {
    bookingState.reset();
    bookingState.beneficiaryLabel = label;
    bookingState.beneficiary = beneficiary;
    setState(() {
      _bookingNavKey = UniqueKey();
      _currentIndex = 2;
    });
  }

  /// Vuelve al tab Inicio después de confirmar reserva.
  void finishBooking() {
    bookingState.reset();
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(tabShell: this),
          const ReservasScreen(),
          RegionalScreen(key: _bookingNavKey, tabShell: this),
          const FamiliaScreen(),
          const PerfilScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: AppColors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 22),
              label: 'Inicio',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today, size: 22),
              label: 'Reservas',
            ),
            BottomNavigationBarItem(
              icon: Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
              label: 'Reservar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people, size: 22),
              label: 'Familia',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person, size: 22),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
