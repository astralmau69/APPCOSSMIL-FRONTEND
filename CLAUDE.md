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
flutter build apk        # Android release build
flutter build ipa        # iOS release build
```

## Architecture

**Pattern:** Feature-based modular architecture with manual state management (setState + shared BookingState object). No Provider/Riverpod/BLoC.

**Key directories:**
- `lib/core/` — Shared code: services (HTTP), models (fromJson/toJson), constants, storage, mock data, reusable widgets
- `lib/features/` — Feature modules, each with `screens/` subfolder (auth, splash, home, booking, reservas, familia, perfil)
- `lib/shell/tab_shell.dart` — Bottom tab navigation (CupertinoTabScaffold, 5 tabs), owns shared BookingState

**Conventions:**
- One file = one responsibility (service files: HTTP only, screen files: UI only, model files: data + JSON serialization)
- Constants centralized in `core/constants/` — never hardcode URLs or colors in screens
- All models are hand-written (no code generation/build_runner)

## Navigation

- Named routes: `/` (SplashScreen) → `/login` (LoginScreen) → `/home` (TabShell)
- CupertinoPageRoute push/pop for screen transitions
- Multi-step booking flow: Regional → Specialty → Schedule → Summary (within tab 2)

## Mock Data Mode

`AppConfig.useMockData` in `core/config/app_config.dart` toggles between real HTTP calls and mock data with simulated delays. Set to `true` for offline development without the backend.

## API & Auth

- OAuth2 Password Grant against `http://10.150.10.13:9999/api/security/oauth/token`
- App-level OAuth2 client credentials in `core/constants/api_constants.dart`
- Tokens stored via `flutter_secure_storage` (Keychain/Keystore)
- Services accept optional `http.Client` parameter for testability

## Key Dependencies

- `http` — REST client
- `flutter_secure_storage` — Token persistence
- `audioplayers` — Splash screen audio
- `pdf` + `printing` — Booking confirmation PDF generation
- `intl` — Date/time formatting
- Dart SDK `^3.8.1`
