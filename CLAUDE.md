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

**Android build:** Kotlin DSL (`build.gradle.kts`), namespace and `applicationId` both `com.cossmil.citamedicapp`, core library desugaring enabled (Java 11 target), NDK 27.0.12077973. Uses debug signing as fallback when `key.properties` is missing; release enables R8 minify + resource shrinking.

There is a single applicationId — no flavors, no id suffix — so `adb install` of any build **replaces** whatever COSSMIL app is on the device rather than installing alongside it. `install -r` keeps app data, but the login session does not survive.

## Architecture

**Pattern:** Feature-based modular architecture with manual state management (setState + shared BookingState object). No Provider/Riverpod/BLoC.

**Key directories:**
- `lib/core/` — Shared code: services (HTTP), models (fromJson/toJson), constants, config, storage, mock data, theme, animations, reusable widgets
- `lib/features/` — Feature modules, each with `screens/` subfolder (auth, splash, home, booking, reservas, familia, perfil, loading, calendario)
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

`CossmilApp` sets `home: const StartupRouter()`. `StartupRouter` (`core/routing/startup_router.dart`) resolves the entry point asynchronously (~50–200 ms) by checking `TokenStorage`, `SessionRestoreService`, and `SecurityService.hasPin()`. All paths eventually route to `SplashScreen`, which then navigates based on session state.

`app.dart` also applies a proportional `TextScaler` (reference width 375 px, clamped 0.85×–1.2×) to all `Text` widgets via the `MaterialApp.builder`, respecting but capping system accessibility scale. `CossmilApp.navigatorKey` is a global key used by `NotificationService` to push modals from outside the widget tree.

## Navigation & Auth Flow

- Entry: `app.dart` defines all named routes via `MaterialApp.routes`; `CossmilApp` wraps `MaterialApp` in `ValueListenableBuilder` for theme reactivity
- Route flow: `StartupRouter` (home) → `SplashScreen` → `/login` → `/loading-data` (LoadingDataScreen) → `/home` (TabShell)
- Local auth branches: `/local-auth` | `/pin-setup` | `/security-setup` | `/password-change` between login and home
- CupertinoPageRoute push/pop for screen transitions within tabs
- Multi-step booking flow (tab 2): Regional → Hospital → Specialty → Doctor → Schedule → Summary
- Calendario flow (tab 3 or similar): Hospital → Specialty → Doctor → Schedule (read-only, no booking)
- Each tab has its own `NavigatorState` key for independent back stacks

## Security Layer

Two separate auth concerns:
- **Remote auth** (`AuthService`) — OAuth2 Password Grant against `ApiConstants.baseUrl`. Tokens stored via `TokenStorage` (flutter_secure_storage).
- **Local auth** (`SecurityService`) — PIN (SHA-256 hashed, never plaintext) + optional biometrics (`local_auth`). Enforces cooldown after failed attempts, inactivity timeout (2 min), and background grace window (15 sec). State managed in `TabShell` via `WidgetsBindingObserver` lifecycle.

`SessionRestoreService` persists the full `UserModel` in secure storage so the app can resume without re-login when the token is still valid. Silently refreshes missing user/beneficiary photos in the background without blocking startup.

**TabShell lifecycle integration:** `WidgetsBindingObserver` monitors app pause/resume. A 30-second polling timer checks `SecurityService.shouldLockOnInactivity()`. A `Listener(onPointerDown:)` with `HitTestBehavior.translucent` resets the activity timer on any touch. Single tap switches tab; double tap on active tab pops to root.

**PHI/PII hardening** (medical data):
- **Screen protection** — `ScreenSecurity` (`core/security/screen_security.dart`, wraps `screen_protector`): Android `FLAG_SECURE` + iOS screenshot block + blur in the app-switcher/recents. `enable()` in `TabShell.initState` (covers every authenticated entry: login, PIN unlock, session restore); `disable()` on logout. Idempotent, never throws (guarded, `kIsWeb`-safe).
- **Log masking** — `LogSanitizer.scrub` (`core/utils/log_sanitizer.dart`) runs on all `AppLogger` output and on the raw `debugPrint`s of `ApiClient`/`ProgramacionService`. Masks Bearer/Basic/JWT, password/token fields, and CI (`ci`/`cedula`/`nrodoc`/`carnet`) — labeled-field only, so `ciudad` and plain ticket/ID numbers are untouched. (All logging is already `kDebugMode`-gated; this is defense-in-depth.)
- **PDF sandbox** — `SecureDocsStore` (`core/services/secure_docs_store.dart`) saves generated PDFs/Word docs only under `getApplicationDocumentsDirectory()/documentos_generados` (private, name-sanitized). `wipeAll()` deletes that whole subdir and is called on logout (both UI paths + `AuthRepository.logout`), so no PHI survives sign-out.

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
- `ApiConstants` — all endpoint paths as static methods (parameterized by IDs). Base URL: `https://api.cossmil.mil.bo` (production, HTTPS). The internal `http://10.150.10.13:9999` is kept commented out for local/VPN testing only.
- `AuthService.login()` uses `AuthResult` sealed class (`AuthSuccess` / `AuthError`)
- Services accept optional `http.Client` / `ApiClient` parameters for testability
- Backend response format: `{ ok, status, message, data: [...] }` wrapper — services parse via the `data` field

## Session Data Layer

Two static in-memory singletons, populated after login and cleared on logout:

- **`UserSession`** (`core/session/user_session.dart`) — holds `UserModel` for the authenticated user. Helpers `UserSession.ageFor(beneficiary)` and `UserSession.genderFor(beneficiary)` return the correct age/gender for filtering (titular vs. beneficiary), used by specialty filters.
- **`AppSessionCache`** (`core/data/app_session_cache.dart`) — holds four preloaded lists: `grupoFamiliar`, `regionales`, `especialidades`, and `fechaServidor`. `isLoaded` flag indicates readiness.

**`InitialDataOrchestrator`** (`core/data/initial_data_orchestrator.dart`) populates `AppSessionCache` on four parallel loads that call the **real `ProgramacionService`** endpoints (production; no stubs here). Each load carries its own timeout: the two **critical** ones (`regionales`, `fechaServidor`) fail fast so startup surfaces a retry; the two **non-critical** ones (`grupoFamiliar`, `especialidades`) degrade to an empty list on timeout/error so a slow endpoint never blocks the titular from booking (grupo familiar is reloaded on-demand in `TabShell._tryEnterBookingTab`). `LoadingDataScreen` (`features/loading/`) calls `loadAll()` and displays animated progress; on failure shows a retry button.

## Mock Data Mode

`AppConfig.useMockData` in `core/config/app_config.dart` is **strictly a local/offline development toggle** — it is `false` in production, so the app runs entirely against the real backend (`ApiClient` + Bearer token). It is a compile-time `const`, so when `false` every `if (AppConfig.useMockData) { … }` branch (and its `core/mock/` data) is tree-shaken out of release builds. Flip it to `true` only to develop without the COSSMIL VPN/backend. Mock data files live in `core/mock/`.

## Calendario Feature

`features/calendario/` is a **read-only** doctor schedule viewer (not a booking flow). Navigation: `CalendarioHospitalScreen` → `SpecialtySelectionScreen` → `DoctorSelectionScreen` → `DoctorScheduleScreen`. Only hospital IDs `1` and `2` (`_kAllowedIdsuc`) are enabled. Uses `MedicoSucModel` and `HorarioMovilSlot` / `HorarioDia` from `core/models/calendario_models.dart`. Doctor photos support two formats: standard Base64 and a legacy signed-integer comma-separated format.

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
- `assets/vof_tutorial/` — Instructor voice clips for the tutorial and Modo Guiado, one mp3 per step (`<id>.mp3`)

## Tutorial & Modo Guiado

Two separate things share the same instructor (`TutorialCoachOverlay` + `TutorialInstructor`):

- **Tutorial (demo)** — `BookingState.isTutorialMode`. Skips every business call and **never** creates an appointment. Three tours: `ficha`, `calendario`, `tramites`.
- **Modo Guiado** — `BookingState.guidedMode`. The **real** booking flow, narrated. Creates a real appointment; the overlay runs with `narrateOnly: true` so the badge says "RESERVA GUIADA" instead of claiming it is a drill. `TabShell.startBooking()` asks which mode via `showBookingModeSheet` before entering the tab.

**What the instructor says lives in one place:** `lib/core/tutorial/tutorial_script.dart` maps each voice clip id to its bubbles. Joined with a space they must equal the line in `tools/rvc/tutorial_lines.json`, which is what the mp3 actually pronounces — `test/core/tutorial_script_test.dart` enforces it. Changing a wording means editing the map, the json, the md, and regenerating that clip (see `tools/rvc/README.md`).
