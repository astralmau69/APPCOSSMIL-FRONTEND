import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/startup_router.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/local_auth_screen.dart';
import 'features/auth/screens/password_change_screen.dart';
import 'features/auth/screens/pin_setup_screen.dart';
import 'features/loading/screens/loading_data_screen.dart';
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
            final mq = MediaQuery.of(context);
            final screenWidth = mq.size.width;
            final isDark = currentThemeMode == ThemeMode.dark;
            final defaultColor =
                isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

            // Web: escala fija 1:1 — el sistema responsive (AppResponsive)
            // se encarga del tamaño de fuentes y espaciado según el ancho real.
            if (kIsWeb) {
              return MediaQuery(
                data: mq.copyWith(textScaler: const TextScaler.linear(1.0)),
                child: DefaultTextStyle(
                  style: TextStyle(
                      decoration: TextDecoration.none, color: defaultColor),
                  child: appChild!,
                ),
              );
            }

            // Móvil nativo: escala proporcional al ancho (375 px = referencia).
            // 320px → 0.85x | 375px → 1.0x | 428px → 1.08x | 600px → 1.2x
            const double refW = 375.0;
            final double wScale = (screenWidth / refW).clamp(0.85, 1.2);
            final double sysScale =
                mq.textScaler.scale(1.0).clamp(0.8, 2.0);

            return MediaQuery(
              data: mq.copyWith(
                  textScaler: TextScaler.linear(wScale * sysScale)),
              child: DefaultTextStyle(
                style: TextStyle(
                    decoration: TextDecoration.none, color: defaultColor),
                child: appChild!,
              ),
            );
          },
          navigatorKey: CossmilApp.navigatorKey,
          title: 'COSSMIL',
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
            '/loading-data': (context) => const LoadingDataScreen(),
            '/home': (context) => const TabShell(),
          },
        );
      },
    );
  }
}
