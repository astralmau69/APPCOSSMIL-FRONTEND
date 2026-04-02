import 'package:flutter/material.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../storage/token_storage.dart';
import '../services/security_service.dart';
import '../services/session_restore_service.dart';
import '../constants/app_colors.dart';

/// Decides the startup route based on persisted session state.
///
/// Returning users (valid token + restorable session) skip the full splash
/// and go straight to local auth (PIN/biometrics) or home.
/// First-time / post-logout users see the full splash with audio.
class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  bool _showSplash = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final hasToken = await TokenStorage.hasToken();
      if (!hasToken) {
        _goSplash();
        return;
      }

      // Parallel: restore session + check PIN
      final results = await Future.wait([
        SessionRestoreService.restoreUserSession(),
        SecurityService.hasPin(),
      ]);
      final restored = results[0];
      final hasPin = results[1];

      if (!mounted) return;

      if (!restored) {
        // Token exists but session data is gone/corrupt — full splash → login
        _goSplash();
        return;
      }

      // Returning user
      if (hasPin) {
        Navigator.pushReplacementNamed(context, '/local-auth');
      } else {
        // Sin PIN/biométrico configurado → no mantener sesión abierta
        await TokenStorage.deleteToken();
        await SessionRestoreService.clearUserSession();
        _goSplash();
      }
    } catch (_) {
      // Any error → safe fallback to full splash
      _goSplash();
    }
  }

  void _goSplash() {
    if (!mounted) return;
    setState(() => _showSplash = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const SplashScreen();
    }

    // Brief branded screen while resolving (~50-200ms).
    // Matches the app scaffold color to avoid any flash.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
    );
  }
}
