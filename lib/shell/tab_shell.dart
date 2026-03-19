import 'package:flutter/material.dart';
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
  late final CupertinoTabController _tabController;
  final bookingState = BookingState();

  // Keys to access the nested navigators.
  final List<GlobalKey<NavigatorState>> _tabNavKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController(initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void goToTab(int index) {
    _tabController.index = index;
  }

  /// Llamado desde HomeScreen al seleccionar un beneficiario.
  void startBooking(String label, BeneficiaryModel? beneficiary) {
    bookingState.reset();
    bookingState.beneficiaryLabel = label;
    bookingState.beneficiary = beneficiary;
    
    // Jump to the booking tab
    _tabController.index = 2;
    // Reset the booking tab's navigation stack so it starts fresh at RegionalScreen
    _tabNavKeys[2].currentState?.popUntil((route) => route.isFirst);
  }

  /// Vuelve al tab Inicio después de confirmar reserva.
  void finishBooking() {
    bookingState.reset();
    _tabController.index = 0;
    // Reset the booking tab just in case
    _tabNavKeys[2].currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CupertinoTabScaffold(
        controller: _tabController,
        tabBar: CupertinoTabBar(
          backgroundColor: AppColors.white,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.textTertiary,
          border: const Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
          items: [
            BottomNavigationBarItem(
              icon: _AnimatedNavIcon(icon: Icons.home, isSelected: false),
              activeIcon: _AnimatedNavIcon(icon: Icons.home, isSelected: true),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: _AnimatedNavIcon(icon: Icons.calendar_today, isSelected: false),
              activeIcon: _AnimatedNavIcon(icon: Icons.calendar_today, isSelected: true),
              label: 'Reservas',
            ),
            BottomNavigationBarItem(
              icon: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                tween: Tween(begin: 1.0, end: _tabController.index == 2 ? 1.15 : 1.0),
                builder: (context, scale, child) => Transform.scale(
                  scale: scale,
                  child: child,
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 2),
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
                    size: 26,
                  ),
                ),
              ),
              label: 'Reservar',
            ),
            BottomNavigationBarItem(
              icon: _AnimatedNavIcon(icon: Icons.people, isSelected: false),
              activeIcon: _AnimatedNavIcon(icon: Icons.people, isSelected: true),
              label: 'Mi Grupo Familiar',
            ),
            BottomNavigationBarItem(
              icon: _AnimatedNavIcon(icon: Icons.person, isSelected: false),
              activeIcon: _AnimatedNavIcon(icon: Icons.person, isSelected: true),
              label: 'Perfil',
            ),
          ],
        ),
        tabBuilder: (context, index) {
          return CupertinoTabView(
            navigatorKey: _tabNavKeys[index],
            builder: (context) {
              return switch (index) {
                0 => HomeScreen(tabShell: this),
                1 => const ReservasScreen(),
                2 => RegionalScreen(tabShell: this),
                3 => const FamiliaScreen(),
                4 => const PerfilScreen(),
                _ => const SizedBox.shrink(),
              };
            },
          );
        },
      ),
    );
  }
}

class _AnimatedNavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;

  const _AnimatedNavIcon({
    required this.icon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 1.0, end: isSelected ? 1.25 : 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Icon(icon, size: 24),
        );
      },
    );
  }
}
