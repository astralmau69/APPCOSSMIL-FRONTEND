import 'package:flutter/cupertino.dart';
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
  final _tabController = CupertinoTabController(initialIndex: 0);
  final bookingState = BookingState();

  // Clave para reiniciar el navigator del tab Reservar
  UniqueKey _bookingNavKey = UniqueKey();

  /// Llamado desde HomeScreen al seleccionar un beneficiario.
  void startBooking(String label, BeneficiaryModel? beneficiary) {
    bookingState.reset();
    bookingState.beneficiaryLabel = label;
    bookingState.beneficiary = beneficiary;
    setState(() {
      _bookingNavKey = UniqueKey();
    });
    _tabController.index = 2;
  }

  /// Vuelve al tab Inicio después de confirmar reserva.
  void finishBooking() {
    bookingState.reset();
    _tabController.index = 0;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        backgroundColor: CupertinoColors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
        ),
        activeColor: AppColors.olive,
        inactiveColor: AppColors.subtleGrey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill, size: 22),
            label: 'Inicio',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar, size: 22),
            label: 'Reservas',
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.olive,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.olive.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.calendar_badge_plus,
                color: CupertinoColors.white,
                size: 24,
              ),
            ),
            label: 'Reservar',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2_fill, size: 22),
            label: 'Familia',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_fill, size: 22),
            label: 'Perfil',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return CupertinoTabView(
              builder: (_) => HomeScreen(tabShell: this),
            );
          case 1:
            return CupertinoTabView(
              builder: (_) => const ReservasScreen(),
            );
          case 2:
            return CupertinoTabView(
              key: _bookingNavKey,
              builder: (_) => RegionalScreen(tabShell: this),
            );
          case 3:
            return CupertinoTabView(
              builder: (_) => const FamiliaScreen(),
            );
          case 4:
            return CupertinoTabView(
              builder: (_) => const PerfilScreen(),
            );
          default:
            return CupertinoTabView(
              builder: (_) => HomeScreen(tabShell: this),
            );
        }
      },
    );
  }
}
