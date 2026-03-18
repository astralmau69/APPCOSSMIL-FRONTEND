# COSSMIL App

## Project Overview

COSSMIL (Corporación del Seguro Social Militar) is a Flutter mobile application designed for military healthcare appointment booking. It features a Cupertino/iOS-style user interface. The frontend acts purely as a REST API consumer, delegating all business logic to the backend.

### Key Technologies
- **Framework:** Flutter (Cupertino UI)
- **Language:** Dart (SDK ^3.8.1)
- **Networking:** `http` for REST calls
- **Security:** `flutter_secure_storage` for token persistence
- **Other Key Packages:** `audioplayers` (splash audio), `pdf` & `printing` (booking confirmation generation), `intl` (date/time formatting)

### Architecture
- **Pattern:** Feature-based modular architecture with manual state management (`setState` + shared `BookingState` object). No third-party state management libraries like Provider, Riverpod, or BLoC are used.
- **Structure:**
  - `lib/core/`: Shared code including HTTP services, models, constants, storage, mock data, and reusable widgets.
  - `lib/features/`: Feature modules with `screens/` subfolders (e.g., auth, splash, home, booking, reservas, familia, perfil).
  - `lib/shell/`: Contains `tab_shell.dart` for bottom tab navigation (CupertinoTabScaffold) and owns the shared `BookingState`.
- **Authentication:** OAuth2 Password Grant flow against a backend server, utilizing app-level client credentials stored in `core/constants/api_constants.dart`.
- **Mock Data Mode:** Supports toggling between real HTTP calls and mock data (with simulated delays) via `AppConfig.useMockData` in `core/config/app_config.dart` for offline development.

## Building and Running

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Run linter
flutter analyze

# Run tests
flutter test

# Build for Android
flutter build apk

# Build for iOS
flutter build ipa
```

## Development Conventions

- **Language:** Spanish is primarily used for UI text, documentation, and in some variable names.
- **Single Responsibility:** Adhere strictly to one responsibility per file:
  - **Services:** Handle HTTP logic only (no UI). Services should accept an optional `http.Client` parameter to facilitate testability.
  - **Screens:** Handle UI only, delegating logic to services.
  - **Models:** Handle data structure and manual JSON serialization (`fromJson`/`toJson`). Avoid using code generation tools like `build_runner`.
- **Constants:** Never hardcode URLs, credentials, or colors directly in UI screens. Centralize all constants within the `lib/core/constants/` directory.
- **Navigation:** Use named routes (e.g., `/login`, `/home`) and `CupertinoPageRoute` for screen transitions.
