# Ridin Mobile App Guidelines & Project Memory

This project is the Flutter mobile client for **Ridin** — real-time school transit and enterprise fleet tracking in Algeria.

---

## 1. Foundational Context & Tech Stack

- **SDK**: Flutter 3.44.2 / Dart 3.12.2 (verify against the installed SDK and pubspec.lock)
- **State Management**: BLoC (`flutter_bloc: ^9.1.1`)
- **HTTP Client**: Dio (`dio: ^5.9.0`) with automated Bearer auth interceptor
- **Real-Time Client**: Centrifuge (`centrifuge: ^0.15.0`) connected to `wss://caresocket.raystate.com/connection/websocket`
- **Secure Storage**: `flutter_secure_storage: ^10.0.0` with `AndroidOptions(resetOnError: true)`
- **Maps & Location**: `flutter_map: ^8.2.2`, `geolocator: ^14.0.2`
- **Scanner**: `mobile_scanner: ^6.0.4`

---

## 2. Directory Structure & Architecture

```text
lib/
├── core/
│   ├── api/          # ApiClient (Dio, token interceptor, 401 handler)
│   ├── constants/    # AppConstants (Mindcare keys, LAN URLs, Centrifugo URLs)
│   ├── network/      # CentrifugoService (WebSocket lifecycle, subscriptions)
│   ├── services/     # LocationService (background geolocator)
│   ├── theme/        # AppTheme (Dark obsidian #0F172A, Amber #F59E0B)
│   └── widgets/      # AppDrawer, AppSplashScreen, RidinLogo (vector painter)
├── features/
│   ├── auth/         # AuthBloc, AuthRepository, LoginScreen, ChangeTemporaryPasswordScreen
│   ├── driver/       # DriverCockpitScreen (active trips, stops, call attempts, GPS)
│   └── parent/       # ParentTrackingScreen (live radar, child tracking, pin stop)
└── main.dart         # Entry point, MultiBlocProvider, PopScope double-tap exit
```

---

## 3. Storage Keys Alignment (Mindcare Standard)

Always use the standard keys defined in `AppConstants`:
- `auth_token`: Plaintext Sanctum bearer token (`Bearer ...`).
- `user_data`: JSON string of authenticated user profile.
- `active_mode`: Active role (`parent` or `driver`).
- `centrifugo_token`: Connection JWT for Centrifugo WebSocket.
- `centrifugo_ws_url`: Public Centrifugo WebSocket URL.

---

## 4. Solved Traps & Standing Constraints (CRITICAL)

### Trap 1: Android Keystore Decryption Exception (`FlutterSecureStorage`)
- **Issue**: `java.lang.SecurityException: Could not decrypt key. decryption failed`.
- **Root Cause**: Android Auto-Backup restored encrypted SharedPreferences XML from Google Drive, while debug reinstalls generated a fresh hardware Keystore master key.
- **Mandatory Rules**:
  1. Keep `android:allowBackup="false"` and `android:fullBackupContent="false"` in `AndroidManifest.xml`.
  2. ALWAYS instantiate `FlutterSecureStorage` with `aOptions: const AndroidOptions(resetOnError: true)`.
  3. ALWAYS guard reads/writes with try/catch helpers (`_safeRead`, `_safeWrite`) in `AuthRepository` and `ApiClient` so crypto failures gracefully clear storage and return `null`.

### Trap 2: Nested Scaffold Drawer Trap
- **Issue**: Drawer hamburger icon disappears, is unclickable, or opens a blank white drawer.
- **Mandatory Rule**: Never nest a `Scaffold` inside another `Scaffold`. The screen root `Scaffold` must directly define `drawer: const AppDrawer()` and use an `AppBar` with standard leading hamburger icon.

### Trap 3: Double-Tap Back Exit Protection
- **Rule**: Handled at root in `main.dart` via `PopScope` with a 2-second timestamp threshold and a localized SnackBar (*"Appuyez à nouveau pour quitter"*). Do NOT add conflicting `PopScope` or `WillPopScope` widgets in child screens.

### Trap 4: RTL Arabization
- **Rule**: Always use directional layout widgets (`EdgeInsetsDirectional`, `AlignmentDirectional`, `CrossAxisAlignment.start`) to ensure Arabic (`'ar'`) renders with full RTL mirroring without layout overflow bugs.

### Trap 5: Mandatory `SafeArea(bottom: true)` on all Bottom Elements
- **Issue**: Floating action buttons, bottom cards, modals, or drawer action footers overlap with the Android gesture navigation pill or 3-button system navigation bar.
- **Mandatory Rule**: ALWAYS wrap bottom-anchored UI components in `SafeArea(top: false, bottom: true, child: ...)` or use `MediaQuery.of(context).padding.bottom`. Never position interactive elements flush to the screen edge without inset protection.

---

## 5. Local Development & Physical Device LAN Connection

- **Host LAN IP**: `192.168.100.9`
- **Backend API**: `http://192.168.100.9:8000/api/v1`
- **Centrifugo WSS**: `wss://caresocket.raystate.com/connection/websocket`
- **Cleartext Traffic**: Keep `android:usesCleartextTraffic="true"` in `AndroidManifest.xml`.
- **ADB Reverse**: Run `adb reverse tcp:8000 tcp:8000` when testing over USB or ADB Wi-Fi.

### Test Credentials
- Parent: `parent@ridin.dz` / `password`
- Driver: `driver@ridin.dz` / `password`
- Business Admin: `business@ridin.dz` / `password`

---

## 6. Real-Device-First Engineering Rule (Zero Fake Features)

- **Authentic Implementations Only**: Never build mock shortcuts, demo auto-fill buttons, fake offline stubs, or simulated UI bypasses in the mobile app.
- **End-to-End Integrity**: Every feature (login, GPS broadcasting, stop acknowledgment, safety checklist, call attempt logging, QR scanning) must communicate with the real backend API (`http://192.168.100.9:8000/api/v1`) and real Centrifugo WebSocket (`caresocket.raystate.com`).
- **Physical Device Validation**: All features are validated on connected physical hardware (e.g. Samsung Galaxy M53 over ADB). If test/scenario data is needed, seed genuine relational database records via `php artisan db:seed` in the backend rather than hardcoding fake data in mobile client code.

---

## 7. Dedicated Skills
- Activate [ridin-mobile](.agents/skills/ridin-mobile/SKILL.md) for ADB streaming, building APKs, and Flutter recipes.
