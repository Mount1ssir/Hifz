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

For a physical device, follow [Run Hifz on an Android phone](#run-hifz-on-an-android-phone) below.

## Project layout

- `lib/app_modules.dart` contains the app's root widget.
- `lib/core/` is for shared infrastructure.
- `lib/domain/` is for pure Dart planning and revision logic.
- `lib/features/` is for feature-specific screens and state.

GitHub Actions runs formatting, analysis, the domain dependency check, and tests
on every push and pull request.

## Run Hifz on an Android phone

### Connect by USB

1. On your phone, open **Settings → About phone** and tap **Build number**
   seven times to enable Developer options. Some phones list it under
   **Software information**.
2. Open **Settings → Developer options** and enable **USB debugging**.
3. Unlock the phone, connect it to your computer with a USB data cable, and tap
   **Allow** when the phone asks to authorize USB debugging.
4. In a terminal at the project root, run `source .hifz-env/activate` in Bash
   if you're using the project-local SDKs. Then check that Flutter sees the phone:

   ```sh
   adb devices -l
   flutter devices
   ```

   If ADB lists the phone as `unauthorized`, unlock it and accept the prompt.
   If the phone is missing, try another data cable or USB port. For Linux
   permissions and Windows USB drivers, see the
   [Android hardware device guide](https://developer.android.com/studio/run/device#setting-up).

### Run live and see code changes

Copy the phone's device ID from `flutter devices` and replace `DEVICE_ID` in
the command below:

```sh
flutter run -d DEVICE_ID
```

Flutter builds, installs, and opens Hifz on the phone. Keep the terminal running.
After saving a Dart change, press **r** in that terminal to hot reload while
keeping the app's current state. Press **R** to restart the app and reset its
in-memory state, or **q** to end the debug session.
[Flutter hot reload guide](https://docs.flutter.dev/tools/hot-reload).

For a cable-free connection on Android 11 or later, put the phone and computer
on the same Wi-Fi network and pair them through **Developer options → Wireless
debugging**. After pairing and connecting, use the device ID shown by
`flutter devices` with the same `flutter run` command.
[Android wireless debugging guide](https://developer.android.com/studio/run/device#wireless).

### Install a debug APK for manual testing

With the phone connected and authorized, build and install the APK. Replace
`DEVICE_ID` with the serial shown by `adb devices -l`.

```sh
flutter build apk --debug
adb -s DEVICE_ID install -r build/app/outputs/flutter-apk/app-debug.apk
```

Open **Hifz** from the phone's app drawer. You can disconnect the phone and
continue testing. To test a later change, build and install the APK again.
ok
