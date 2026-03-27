# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

COSSMIL (Corporación del Seguro Social Militar) — a Flutter mobile app for military healthcare appointment booking. Cupertino/iOS-style UI. All business logic lives on the backend; the frontend is a pure REST consumer.

**Language:** Spanish (UI text, variable names in some places, documentation).

## Build & Run Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run in debug mode
flutter analyze          # Run linter (flutter_lints)
flutter test             # Run tests
flutter test test/widget_test.dart  # Run a single test file
flutter build apk        # Android release build
flutter build ipa        # iOS release build
```

**Android build:** Kotlin DSL (`build.gradle.kts`), namespace `bo.mil.cossmil.app`, core library desugaring enabled (Java 11 target), NDK 27.0.12077973. Uses debug signing as fallback when `key.properties` is missing.

## Architecture

**Pattern:** Feature-based modular architecture with manual state management (setState + shared BookingState object). No Provider/Riverpod/BLoC.

**Key directories:**
- `lib/core/` — Shared code: services (HTTP), models (fromJson/toJson), constants, config, storage, mock data, theme, animations, reusable widgets
- `lib/features/` — Feature modules, each with `screens/` subfolder (auth, splash, home, booking, reservas, familia, perfil)
- `lib/shell/` — Tab navigation shell: `tab_shell.dart` (CupertinoTabScaffold, 5 tabs, owns BookingState) + `widgets/floating_nav_bar.dart`

**Conventions:**
- One file = one responsibility (service files: HTTP only, screen files: UI only, model files: data + JSON serialization)
- Constants centralized in `core/constants/` — never hardcode URLs or colors in screens
- All models are hand-written (no code generation/build_runner)
- Features contain only `screens/` subfolders — no models or services within features; all shared code lives in `lib/core/`

## Startup & Initialization

`main.dart` initialization order matters:
1. `WidgetsFlutterBinding.ensureInitialized()`
2. `NotificationService.initialize()` (timezone config for America/La_Paz + channel registration)
3. `SystemChrome.setPreferredOrientations()` (portrait only)
4. `runApp(CossmilApp())`

## Navigation & Auth Flow

- Entry: `app.dart` defines all named routes via `MaterialApp.routes`; `CossmilApp` wraps `MaterialApp` in `ValueListenableBuilder` for theme reactivity
- Route flow: `/` (SplashScreen) → `/login` (LoginScreen) → `/local-auth` | `/pin-setup` | `/security-setup` → `/home` (TabShell)
- CupertinoPageRoute push/pop for screen transitions within tabs
- Multi-step booking flow: Regional → Specialty → Schedule → Summary (within tab 2)
- Each tab has its own `NavigatorState` key for independent back stacks

## Security Layer

Two separate auth concerns:
- **Remote auth** (`AuthService`) — OAuth2 Password Grant against `ApiConstants.baseUrl`. Tokens stored via `TokenStorage` (flutter_secure_storage).
- **Local auth** (`SecurityService`) — PIN (SHA-256 hashed, never plaintext) + optional biometrics (`local_auth`). Enforces cooldown after failed attempts, inactivity timeout (2 min), and background grace window (15 sec). State managed in `TabShell` via `WidgetsBindingObserver` lifecycle.

`SessionRestoreService` persists the full `UserModel` in secure storage so the app can resume without re-login when the token is still valid. Silently refreshes missing user/beneficiary photos in the background without blocking startup.

**TabShell lifecycle integration:** `WidgetsBindingObserver` monitors app pause/resume. A 30-second polling timer checks `SecurityService.shouldLockOnInactivity()`. A `Listener(onPointerDown:)` with `HitTestBehavior.translucent` resets the activity timer on any touch. Single tap switches tab; double tap on active tab pops to root.

## State & Theme

- `BookingState` (mutable PODO in `tab_shell.dart`) holds the multi-step booking flow selections; passed down to booking screens
- `ThemeManager` — `ValueNotifier<ThemeMode>` for dark/light mode switching without any state management library
- `AppTheme` defines both light and dark `ThemeData`; `AppColors` centralizes the palette

**Design token system** (`core/theme/app_constants.dart`): `AppSpacing` (xs→xxl: 4→48), `AppTypography` (15 text styles), `AppShadows` (6 elevation levels), `AppDurations` (ultra 100ms → extra 1000ms), `AppCurves` (snappy, smooth, bounce, elasticity). Use these tokens instead of raw values.

## Notifications

`NotificationService` (`core/services/notification_service.dart`) manages booking reminders:
- Two channels: `cossmil_booking` (immediate confirmations) and `cossmil_reminder` (scheduled reminders)
- Three-tier reminder schedule: morning of appointment (8:00 AM), 2 hours before, 30 minutes before
- Notification IDs derived from ticket numbers via modulo arithmetic to avoid collisions
- Zone-aware scheduling using `tz.TZDateTime` (America/La_Paz timezone)

## Responsive Layout

`core/extensions/responsive_extensions.dart` provides device-aware sizing:
- Breakpoints: phoneSmall (<375) → phoneMedium (375-428) → phoneLarge (428-600) → tabletSmall (600-768) → tabletMedium (768-1024) → tabletLarge (1024+)
- `ResponsiveBuilder` widget provides `ResponsiveData`; `ResponsiveContainer` auto-limits max-width on tablets
- Context extensions: `context.isSmallPhone`, `context.isTablet`, `context.isLandscape`

## API Layer

- `ApiClient` — centralized HTTP client that auto-injects Bearer token from `TokenStorage` on every request. Wraps responses in `ApiClientResponse` (success/error sealed pattern). On 401, auto-retries once after token refresh; uses a `_refreshInProgress` Future to prevent concurrent refresh attempts.
- `ApiConstants` — all endpoint paths as static methods (parameterized by IDs). Base URL: `http://10.150.10.13:9999`
- `AuthService.login()` uses `AuthResult` sealed class (`AuthSuccess` / `AuthError`)
- Services accept optional `http.Client` / `ApiClient` parameters for testability
- Backend response format: `{ ok, status, message, data: [...] }` wrapper — services parse via the `data` field

## Mock Data Mode

`AppConfig.useMockData` in `core/config/app_config.dart` toggles between real HTTP calls and mock data with simulated delays. Set to `true` for offline development without the backend. Mock data files live in `core/mock/`.

## Key Dependencies

- `http` — REST client
- `flutter_secure_storage` — Token + session persistence (Keychain/Keystore)
- `local_auth` — Biometric authentication
- `crypto` — PIN hashing (SHA-256)
- `audioplayers` — Splash screen audio
- `pdf` + `printing` — Booking confirmation PDF generation
- `intl` — Date/time formatting
- `animate_do` — Declarative animations
- `geolocator` — Device location for nearest regional
- `flutter_local_notifications` + `timezone` — Scheduled appointment reminders (America/La_Paz)
- `url_launcher` — External links
- `path_provider` + `open_file` — File generation and opening
- Dart SDK `^3.8.1`

## Logging

`AppLogger` (`core/utils/app_logger.dart`) — zero overhead in release (all wrapped in `kDebugMode`). Tag-based structured logging with methods: `debug`, `info`, `warn`, `error`. Use this instead of `print()`.

## Assets

- `assets/images/` — App images including `cossmil_logo.png` (used in PDF generation and launcher icon)
- `assets/vof/` — Voice-over audio files for splash screen
