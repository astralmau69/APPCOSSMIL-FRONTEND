import 'dart:ui';
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

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void goToTab(int index) {
    setState(() => _currentIndex = index);
  }

  /// Llamado desde HomeScreen al seleccionar un beneficiario.
  void startBooking(String label, BeneficiaryModel? beneficiary) {
    bookingState.reset();
    bookingState.beneficiaryLabel = label;
    bookingState.beneficiary = beneficiary;
    setState(() => _currentIndex = 2);
    _tabNavKeys[2].currentState?.popUntil((route) => route.isFirst);
  }

  /// Vuelve al tab Inicio después de confirmar reserva.
  void finishBooking() {
    bookingState.reset();
    setState(() => _currentIndex = 0);
    _tabNavKeys[2].currentState?.popUntil((route) => route.isFirst);
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(
          5,
          (i) => CupertinoTabView(
            navigatorKey: _tabNavKeys[i],
            builder: (_) => _screenForIndex(i),
          ),
        ),
      ),
      bottomNavigationBar: _buildBar(bottomPadding),
    );
  }

  // ── Premium Bottom Bar ──────────────────────────────────────────────────

  static const _barH = 82.0;
  static const _protrusion = 28.0;

  Widget _buildBar(double bottomPad) {
    return SizedBox(
      height: _barH + bottomPad + _protrusion,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glass background
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barH + bottomPad,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.88),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.35),
                        width: 0.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Regular tab items
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPad,
            height: _barH,
            child: Row(
              children: [
                _tab(0, CupertinoIcons.house, CupertinoIcons.house_fill,
                    'Inicio'),
                _tab(1, CupertinoIcons.time, CupertinoIcons.time_solid,
                    'Reservas'),
                const Expanded(child: SizedBox()),
                _tab(3, CupertinoIcons.person_2,
                    CupertinoIcons.person_2_fill, 'Familia'),
                _tab(4, CupertinoIcons.person_crop_circle,
                    CupertinoIcons.person_crop_circle_fill, 'Perfil'),
              ],
            ),
          ),

          // Central floating button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: _centralButton()),
          ),
        ],
      ),
    );
  }

  // ── Regular Tab Item ────────────────────────────────────────────────────

  Widget _tab(int idx, IconData icon, IconData activeIcon, String label) {
    final active = _currentIndex == idx;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = idx),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: active ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Transform.scale(
                scale: 1.0 + 0.15 * v,
                child: Icon(
                  active ? activeIcon : icon,
                  size: 32,
                  color: Color.lerp(
                      AppColors.textTertiary, AppColors.primary, v),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: active ? 5 : 0,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Central Floating Reservar Button ────────────────────────────────────

  Widget _centralButton() {
    final active = _currentIndex == 2;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) {
              final glow = active
                  ? Tween<double>(begin: 0.25, end: 0.50).evaluate(
                      CurvedAnimation(
                          parent: _pulseCtrl, curve: Curves.easeInOut))
                  : 0.25;
              return AnimatedScale(
                scale: active ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: const [Color(0xFF1D8FCC), Color(0xFF0C4A6E)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: glow),
                        blurRadius: active ? 20 : 12,
                        offset: const Offset(0, 4),
                        spreadRadius: active ? 2 : 0,
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            child: const Icon(
              CupertinoIcons.calendar_badge_plus,
              color: AppColors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reservar',
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
