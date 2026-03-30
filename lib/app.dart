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
            // Se obtiene la configuración actual de MediaQuery
            final mediaQueryData = MediaQuery.of(context);
            
            // Se calcula un nuevo TextScaler que incrementa el tamaño base en un 25% 
            // (16pt pasa a ser 20pt, cumpliendo con los +4 puntos solicitados)
            // Esto afecta a toda la aplicación de forma adaptativa y global.
            final double currentScale = mediaQueryData.textScaler.scale(1.0);
            final TextScaler customTextScaler = TextScaler.linear(currentScale * 1.25);

            // Ensures ALL Text widgets have decoration:none by default.
            final defaultColor = currentThemeMode == ThemeMode.dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
            
            return MediaQuery(
              data: mediaQueryData.copyWith(textScaler: customTextScaler),
              child: DefaultTextStyle(
                style: TextStyle(
                  decoration: TextDecoration.none,
                  color: defaultColor,
                  fontFamily: '.SF Pro Text',
                ),
                child: appChild!,
              ),
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
