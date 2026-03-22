import 'package:flutter/cupertino.dart';
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

class TabShellState extends State<TabShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final bookingState = BookingState();

  final List<GlobalKey<NavigatorState>> _tabNavKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  late final CupertinoTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void goToTab(int index) {
    setState(() => _currentIndex = index);
    _tabController.index = index;
  }

  /// Llamado desde HomeScreen al seleccionar un beneficiario.
  void startBooking(String label, BeneficiaryModel? beneficiary) {
    bookingState.reset();
    bookingState.beneficiaryLabel = label;
    bookingState.beneficiary = beneficiary;
    goToTab(2);
    _tabNavKeys[2].currentState?.popUntil((route) => route.isFirst);
  }

  /// Vuelve al tab Inicio después de confirmar reserva.
  void finishBooking() {
    bookingState.reset();
    goToTab(0);
    _tabNavKeys[0].currentState?.popUntil((route) => route.isFirst);
  }

  Widget _screenForIndex(int index) {
    return switch (index) {
      0 => HomeScreen(tabShell: this),
      1 => const ReservasScreen(),
      2 => RegionalScreen(tabShell: this),
      3 => const FamiliaScreen(),
      4 => const PerfilScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _tabController,
      backgroundColor: AppColors.background,
      tabBar: CupertinoTabBar(
        backgroundColor: AppColors.white.withValues(alpha: 0.92),
        activeColor: AppColors.primary,
        inactiveColor: AppColors.textTertiary,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        onTap: (index) {
          if (index == _currentIndex) {
            _tabNavKeys[index].currentState?.popUntil((route) => route.isFirst);
          }
          setState(() => _currentIndex = index);
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house, size: 28),
            activeIcon: Icon(CupertinoIcons.house_fill, size: 28),
            label: 'Inicio',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.time, size: 28),
            activeIcon: Icon(CupertinoIcons.time_solid, size: 28),
            label: 'Reservas',
          ),
          BottomNavigationBarItem(
            icon: _ReservingTabIcon(isActive: _currentIndex == 2),
            label: 'Reservar',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2, size: 28),
            activeIcon: Icon(CupertinoIcons.person_2_fill, size: 28),
            label: 'Familia',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_crop_circle, size: 28),
            activeIcon: Icon(CupertinoIcons.person_crop_circle_fill, size: 28),
            label: 'Perfil',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          navigatorKey: _tabNavKeys[index],
          builder: (context) => _screenForIndex(index),
        );
      },
    );
  }
}

/// Tab icon for reservations (Reservar) - extracted to avoid rebuild on every TabShell setState
class _ReservingTabIcon extends StatelessWidget {
  final bool isActive;

  const _ReservingTabIcon({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        CupertinoIcons.calendar_badge_plus,
        size: 24,
        color: isActive ? AppColors.white : AppColors.primary,
      ),
    );
  }
}

