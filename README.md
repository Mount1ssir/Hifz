# Hifz

An Android-first Flutter app for Quran memorization (Hifz) and revision
(Muraja’ah). See the [development roadmap](Quran%20Memorization%20App%20Development%20Roadmap.md)
for the planned Quran data import, scheduling algorithms, and MVP.

## Development setup

This project uses Flutter 3.50.0 stable, which includes Dart 3.14.0. Install
[Flutter](https://docs.flutter.dev/install) and the
[Android toolchain](https://docs.flutter.dev/platform-integration/android/setup).
Use `flutter doctor -v` to check the toolchain.

In a workspace with the project-local SDKs under `.hifz-env/`, run
`source .hifz-env/activate` from the project root in Bash.

From the project root:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Connect an Android phone with USB debugging enabled or start an Android emulator.
Run `flutter devices` to list targets, then run `flutter run`.

## Project layout

- `lib/app_modules.dart` contains the app's root widget.
- `lib/core/` is for shared infrastructure.
- `lib/domain/` is for pure Dart planning and revision logic.
- `lib/features/` is for feature-specific screens and state.

GitHub Actions runs formatting, analysis, the domain dependency check, and tests
on every push and pull request.
