# COSSMIL Flutter App

Flutter mobile app for military healthcare appointment booking (Corporación del Seguro Social Militar). Cupertino/iOS-style UI. All business logic lives on the backend; the frontend is a pure REST consumer.

**Language:** Spanish (UI text, variable names, documentation).

## Commands

```bash
flutter pub get                        # Install dependencies
flutter run                            # Run in debug mode
flutter analyze                        # Run linter (flutter_lints)
flutter test                           # Run all tests
flutter test test/widget_test.dart     # Run single test file
flutter build apk                      # Android release build
flutter build ipa                      # iOS release build
```

## Architecture

**Pattern:** Feature-based modular architecture with manual state management (`setState` + shared `BookingState` object). No Provider/Riverpod/BLoC.

**Key directories:**
- `lib/core/` — Shared code: services, models, constants, config, storage, mock data, theme, widgets
- `lib/features/` — Feature modules with `screens/` subfolders (auth, splash, home, booking, reservas, familia, perfil)
- `lib/shell/` — Tab navigation shell (`CupertinoTabScaffold`, 5 tabs, owns `BookingState`)

**Booking flow (within tab 2):** Regional → Specialty → Schedule → Summary

## Key Conventions

### Single Responsibility
- **Services:** HTTP logic only, no UI. Accept optional `http.Client`/`ApiClient` for testability.
- **Screens:** UI only, delegate logic to services.
- **Models:** Data structure + manual `fromJson`/`toJson`. No code generation/build_runner.

### Constants & Tokens
- Never hardcode URLs, credentials, or colors in screens — use `lib/core/constants/`
- Use design tokens from `core/theme/app_constants.dart`:
  - `AppSpacing` (xs→xxl: 4→48)
  - `AppTypography` (15 text styles)
  - `AppShadows` (6 elevation levels)
  - `AppDurations` / `AppCurves` (animation constants)

### Feature Structure
Features contain only `screens/` subfolders. All models and services live in `lib/core/`.

## Authentication

Two separate auth concerns:
- **Remote auth** (`AuthService`) — OAuth2 Password Grant. Tokens stored via `TokenStorage` (flutter_secure_storage).
- **Local auth** (`SecurityService`) — PIN (SHA-256 hashed) + optional biometrics. Enforces cooldown, inactivity timeout (2 min), background grace window (15 sec).

## API Layer

- `ApiClient` — Centralized HTTP client with auto-injected Bearer token. Returns `ApiClientResponse` sealed class (success/error). Auto-retries on 401 after token refresh.
- `ApiConstants` — All endpoint paths as static methods. Base URL: `https://api.cossmil.mil.bo` (production, HTTPS). The internal `http://10.150.10.13:9999` is kept commented out for local/VPN testing only.
- Backend response format: `{ ok, status, message, data: [...] }` — parse via `data` field.

## Mock Data Mode

Toggle `AppConfig.useMockData` in `core/config/app_config.dart` for offline development. Mock data lives in `core/mock/`.

## Navigation

- Routes defined in `app.dart` via `MaterialApp.routes`
- Flow: `/` (Splash) → `/login` → `/local-auth` | `/pin-setup` | `/security-setup` → `/home` (TabShell)
- Use `CupertinoPageRoute` for screen transitions
- Each tab has its own `NavigatorState` key for independent back stacks

## Startup Order (main.dart)

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `NotificationService.initialize()` (America/La_Paz timezone)
3. `SystemChrome.setPreferredOrientations()` (portrait only)
4. `runApp(CossmilApp())`

## Logging

Use `AppLogger` (`core/utils/app_logger.dart`) instead of `print()`. Zero overhead in release builds (wrapped in `kDebugMode`).
