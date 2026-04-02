import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/startup_router.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/local_auth_screen.dart';
import 'features/auth/screens/password_change_screen.dart';
import 'features/auth/screens/pin_setup_screen.dart';
import 'features/perfil/screens/security_setup_screen.dart';
import 'shell/tab_shell.dart';
import 'core/theme/theme_manager.dart';

class CossmilApp extends StatefulWidget {
  const CossmilApp({super.key});

  /// Global navigator key — used by NotificationService to show modals.
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<CossmilApp> createState() => _CossmilAppState();
}

class _CossmilAppState extends State<CossmilApp> {

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          builder: (context, appChild) {
            final mediaQueryData = MediaQuery.of(context);
            final screenWidth = mediaQueryData.size.width;

            // Escalado proporcional al ancho de pantalla
            // 320px → 0.88x | 375px → 1.0x | 428px → 1.08x | 600px → 1.15x
            const double referenceWidth = 375.0;
            final double widthScale = (screenWidth / referenceWidth).clamp(0.85, 1.2);

            // Respetar accesibilidad del sistema pero limitar para no romper layouts
            final double systemScale = mediaQueryData.textScaler.scale(1.0).clamp(0.8, 1.35);

            final TextScaler customTextScaler = TextScaler.linear(widthScale * systemScale);

            // Ensures ALL Text widgets have decoration:none by default.
            final defaultColor = currentThemeMode == ThemeMode.dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
            
            return MediaQuery(
              data: mediaQueryData.copyWith(textScaler: customTextScaler),
              child: DefaultTextStyle(
                style: TextStyle(
                  decoration: TextDecoration.none,
                  color: defaultColor,
                ),
                child: appChild!,
              ),
            );
          },
          navigatorKey: CossmilApp.navigatorKey,
          title: 'COSSMIL Flow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(context),
          darkTheme: AppTheme.dark(context),
          themeMode: currentThemeMode,
          home: const StartupRouter(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/local-auth': (context) => const LocalAuthScreen(),
            '/pin-setup': (context) => const PinSetupScreen(),
            '/security-setup': (context) => const SecuritySetupScreen(),
            '/password-change': (context) => const PasswordChangeScreen(),
            '/home': (context) => const TabShell(),
          },
        );
      },
    );
  }
}
