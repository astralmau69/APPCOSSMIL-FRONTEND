import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'shell/tab_shell.dart';
import 'core/theme/theme_manager.dart';

class CossmilApp extends StatefulWidget {
  const CossmilApp({super.key});

  @override
  State<CossmilApp> createState() => _CossmilAppState();
}

class _CossmilAppState extends State<CossmilApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _wasInBackground = false;
  bool _splashShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasInBackground = true;
    }

    if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      _showSplashOverlay();
    }
  }

  void _showSplashOverlay() {
    if (_splashShowing) return;
    _splashShowing = true;

    _navigatorKey.currentState?.push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => const SplashScreen(isOverlay: true),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    ).then((_) {
      _splashShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          builder: (context, appChild) {
            // Ensures ALL Text widgets have decoration:none by default.
            final defaultColor = currentThemeMode == ThemeMode.dark ? Colors.white : AppColors.textPrimary;
            return DefaultTextStyle(
              style: TextStyle(
                decoration: TextDecoration.none,
                color: defaultColor,
                fontFamily: '.SF Pro Text',
              ),
              child: appChild!,
            );
          },
          navigatorKey: _navigatorKey,
          title: 'COSSMIL Flow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          home: const SplashScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const TabShell(),
          },
        );
      },
    );
  }
}
