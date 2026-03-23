import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/services/security_service.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/auth/screens/local_auth_screen.dart';
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
import 'widgets/floating_nav_bar.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSecurityLock();
    }
  }

  Future<void> _checkSecurityLock() async {
    final hasPin = await SecurityService.hasPin();
    if (hasPin) {
      // Bloquear con un modal de splash que luego pida el PIN
      if (!mounted) return;
      
      // Usamos una ruta transparente o un fullScreenDialog
      // En este caso, mostraremos el SplashScreen con isOverlay: true
      // el cual al terminar hará Navigator.pop() y luego mostramos el LocalAuthScreen.
      
      await Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (context) => const SplashScreen(isOverlay: true),
        ),
      );

      if (!mounted) return;
      
      // Al volver del splash overlay, pedimos autenticación
      // Si el usuario ya está en LocalAuthScreen no hace falta (aunque didChangeAppLifecycleState se dispara al volver)
      // Pero LocalAuthScreen no se usa como overlay, sino como pantalla principal.
      // Para re-bloqueo en caliente, mejor pushear el LocalAuthScreen.
      
      await Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (context) => const LocalAuthScreen(),
        ),
      );
    }
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final navState = _tabNavKeys[_currentIndex].currentState;
        final canPopInternal = await navState?.maybePop() ?? false;
        
        if (!canPopInternal) {
          if (_currentIndex != 0) {
            // Si no estamos en inicio, volver a inicio
            goToTab(0);
          } else {
            // Si ya estamos en inicio y no hay nada que popear, salir de la app
            // Por seguridad, usamos SystemNavigator.pop() o permitimos la propagación
            // En Flutter moderno con PopScope(canPop: false), debemos manejarlo.
            // Si realmente queremos salir:
            final bool? shouldExit = await showCupertinoDialog<bool>(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('Salir'),
                content: const Text('¿Desea cerrar la aplicación?'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('No'),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: const Text('Sí'),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            );
            
            if (shouldExit == true) {
              // Permitimos el pop real o cerramos
              SystemChannels.platform.invokeMethod('SystemNavigator.pop');
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(5, (index) {
            return CupertinoTabView(
              navigatorKey: _tabNavKeys[index],
              builder: (context) => _screenForIndex(index),
            );
          }),
        ),
        bottomNavigationBar: FloatingNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == _currentIndex) {
              _tabNavKeys[index].currentState?.popUntil((route) => route.isFirst);
            } else {
              goToTab(index);
            }
          },
        ),
      ),
    );
  }
}

