---
name: ridin-mobile
description: >-
  Use this skill whenever working on the Ridin Flutter mobile app (Dart 3, Flutter 3.44.2, BLoC, Dio, Centrifugo Dart, FlutterSecureStorage, Android ADB). Covers testing, building debug APKs, streaming builds to physical devices via ADB, BLoC pattern recipes, and debugging network/storage issues.
---

# Ridin Mobile Development Skill

Operational runbook and development workflows for the Ridin Flutter mobile application.

---

## 1. Quick Commands & Verification

Always run analysis and tests before and after code changes:

```bash
# Static analysis (must report 0 issues)
flutter analyze

# Unit tests
flutter test

# Run specific test
flutter test test/auth_repository_test.dart
```

---

## 2. Building & Deploying to Connected Physical Devices

### 1. Build Debug APK
```bash
flutter build apk --debug
```
Output path: `build/app/outputs/flutter-apk/app-debug.apk`

### 2. Check Attached Devices
```bash
adb devices
```

### 3. Stream Install to Physical Device
```bash
adb -s <device_id> install -r build/app/outputs/flutter-apk/app-debug.apk
```

### 4. Launch Application
```bash
adb -s <device_id> shell am start -n com.raystate.ridin/.MainActivity
```

### 5. Clear Corrupt Data or Reset Keystore
```bash
adb -s <device_id> shell pm clear com.raystate.ridin
```

---

## 3. Centrifugo Real-Time Event Handling

- **Service**: `CentrifugoService` in `lib/core/network/centrifugo_service.dart`
- **Connecting**:
  ```dart
  await centrifugoService.connect(
    wsUrl: AppConstants.defaultCentrifugoWsUrl,
    token: centrifugoToken,
  );
  ```
- **Subscribing to Trip Stream**:
  ```dart
  await centrifugoService.subscribeToChannel(
    channel: 'trips:$tripId',
    token: subscriptionToken,
    onData: (payload) {
      if (payload['event'] == 'location_update') {
        // update live bus coordinate on map
      }
    },
  );
  ```

---

## 4. Common Recipes

### Adding a Screen with Universal AppDrawer
Ensure the root `Scaffold` includes `AppDrawer`:

```dart
import '../../../core/widgets/app_drawer.dart';

class MyFeatureScreen extends StatelessWidget {
  const MyFeatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Feature'),
        centerTitle: true,
      ),
      drawer: const AppDrawer(),
      body: const SafeArea(child: ...),
    );
  }
}
```

### Safe Secure Storage Access
Always use the guarded methods on `AuthRepository` or pass `AndroidOptions(resetOnError: true)`:

```dart
static const _androidOptions = AndroidOptions(resetOnError: true);
final storage = const FlutterSecureStorage(aOptions: _androidOptions);
```

### Always Use `SafeArea(bottom: true)` for Bottom Elements
Any widget positioned near the bottom edge (floating card, modal, or drawer footer) MUST wrap its content in `SafeArea(top: false, child: ...)` to prevent overlap with Android navigation bars:

```dart
Positioned(
  bottom: 16,
  left: 16,
  right: 16,
  child: SafeArea(
    top: false,
    child: MyBottomCard(),
  ),
)
```

---

## 5. Physical Device Realism (Zero Fake Features)

- **Authentic Verification**: Never introduce dummy bypasses, fake offline buttons, or hardcoded UI stubs.
- **Real Backend Communication**: All operations must execute against the live backend API and Centrifugo instances.
- **Seeded Relational Data**: Rely on backend seeders (`php artisan db:seed`) to create realistic Alger transit scenarios.

---

## 6. Logcat Debugging Cheatsheet

```bash
# Filter Flutter logs
adb logcat -s flutter

# Filter SecureStorage & Keystore logs
adb logcat | grep -iE "FlutterSecureStorage|keystore2"

# Filter crashes
adb logcat -d | grep -iE "FATAL EXCEPTION|AndroidRuntime"
```
