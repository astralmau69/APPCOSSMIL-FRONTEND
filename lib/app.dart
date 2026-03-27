import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/local_auth_screen.dart';
import 'features/auth/screens/pin_setup_screen.dart';
import 'features/perfil/screens/security_setup_screen.dart';
import 'shell/tab_shell.dart';
import 'core/theme/theme_manager.dart';

class CossmilApp extends StatefulWidget {
  const CossmilApp({super.key});

  @override
  State<CossmilApp> createState() => _CossmilAppState();
}

class _CossmilAppState extends State<CossmilApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          builder: (context, appChild) {
            // Ensures ALL Text widgets have decoration:none by default.
            final defaultColor = currentThemeMode == ThemeMode.dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
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
            '/local-auth': (context) => const LocalAuthScreen(),
            '/pin-setup': (context) => const PinSetupScreen(),
            '/security-setup': (context) => const SecuritySetupScreen(),
            '/home': (context) => const TabShell(),
          },
        );
      },
    );
  }
}
