# Ridin mobile

Flutter school-transit client for drivers and parents. Keep the existing BLoC feature structure, shared Dio client, secure storage helpers and Centrifugo service.

## Toolchain

- Flutter 3.44.2 / Dart 3.12.2
- Java 17 and the Android SDK
- Dependency versions are locked in `pubspec.lock`; do not upgrade them as part of routine setup.

## Local development

```sh
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE_URL=http://192.168.100.9:8000/api/v1
```

Run the backend on `0.0.0.0:8000` for a physical device on the same network. Verify the host address before using it; the LAN address above is a development default. USB testing can use `adb reverse tcp:8000 tcp:8000` with `API_BASE_URL=http://127.0.0.1:8000/api/v1`.

Never use production accounts or child data for automated tests. Tests isolate HTTP at the test boundary; the application itself uses real services.

## Baseline checks

```sh
flutter analyze
flutter test
flutter build apk --debug
```

The GitHub workflow runs the same checks with the pinned Flutter version. A debug APK proves Android compilation, not production readiness. Release signing, real push registration, reliable background/offline tracking and production endpoints remain separate release work. iOS builds require validation on macOS.

Read `AGENTS.md` and `.agents/skills/ridin-mobile/SKILL.md` before changes. Keep keys, signing credentials, device state and generated build output out of Git.
