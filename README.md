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

## Quran data

The app bundles the Tanzil Hafs text and metadata and stores memorization progress
in a separate Drift database. See the [data guide](docs/quran-data.md) for source
attribution, rebuilding, verification, and pending layout and device checks.

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

## How Hifz is organized and what its dependencies do

Hifz is a Flutter mobile app written in Dart. It currently opens its local
databases and shows the starter screen. The memorization and revision algorithms
are being built in the domain layer. Onboarding, daily plans, and recall screens
are later roadmap tasks.

### The architecture

| Part | Location | Responsibility |
| --- | --- | --- |
| Startup | `lib/main.dart` | Initialize Flutter, register text attribution, and open the databases before showing the app. |
| App and screens | `lib/app_modules.dart`, `lib/features/` | Present information and handle learner actions. Feature screens will call the planning and storage layers. |
| Domain logic | `lib/domain/` | Calculate memorization ranges, daily portions, and revision partitions using pure Dart. These calculations can be tested without a phone. |
| Storage | `lib/core/data/` | Read Quran data and save learner progress. |
| Import tools | `tool/`, `data/sources/` | Turn pinned source downloads into a verified database before the app is built. |
| Bundled assets | `assets/data/` | Ship Quran data and its attribution with the app for offline use. |

There are two SQLite databases. `quran.db` contains the Quran text and structural
metadata and is opened read-only. `user.db` stores the learner's progress.
A progress entry references an ayah by its ID, riwayah, and numbering identity.
This lets us update the bundled text database while retaining saved progress.

For example, a future Today screen will load the learner's memorized ayahs from
`user.db`, pass them and the daily quota to `HifzPlanner`, then read the assigned
ayah text from `quran.db`. Completing the portion will save progress in `user.db`.

### Tanzil and QUL

**Tanzil** supplies the Quran text used in Hifz, plus metadata such as surah
counts and page and juz boundaries. The downloaded text is preserved exactly,
and the import checks its checksum. This data is already bundled.
[Tanzil](https://tanzil.net/download/)

**QUL** means **Quranic Universal Library**, a resource collection maintained by
Tarteel. It distributes Quran datasets, including information describing how
words are arranged on the lines of a printed mushaf.
[QUL overview](https://qul.tarteel.ai/faq)

Hifz needs that layout information for quotas such as “memorize five lines per
day.” A phone wraps text differently depending on its screen size and font.
A printed-mushaf line quota therefore needs a fixed layout mapping words to
printed pages and lines. Joining those mappings to ayahs tells the planner how
many lines each ayah occupies. The planner can then fill a quota while keeping
ayahs whole. Our page-quota design uses the selected layout's lines-per-page
conversion.

The selected QUL layout and word-script licenses are still unresolved, so those
datasets are awaiting import. Verse-based planning works with the bundled data.
The weighted planner accepts verified line weights when they become available.
The planned QUL import happens during development; the app will read the
resulting bundled data offline.
[Layout resource](https://qul.tarteel.ai/resources/mushaf-layout/15/licence),
[word-script resource](https://qul.tarteel.ai/resources/quran-script/57/licence).

### Installed packages

| Dependency | Why Hifz uses it |
| --- | --- |
| Flutter SDK | Runs the app and provides widgets, rendering, platform integration, and asset loading. |
| `material_ui` | Provides Material Design widgets for the app interface. |
| `sqlite3` | Opens and queries the bundled Quran SQLite database, including read-only access. |
| `drift` | Manages the learner database with typed queries and a schema that can evolve through migrations. |
| `path_provider` | Finds the phone's application storage directory. |
| `path` | Builds filesystem paths correctly across platforms. |
| `crypto` | Computes SHA-256 checksums to detect changed or damaged database assets. |
| `flutter_test` | Runs automated widget and Dart logic tests on the development machine. |
| `flutter_lints` | Supplies code-quality rules used by the analyzer. |
| `drift_dev` and `build_runner` | Generate the Dart database code during development. |

The Python import and validation tools use Python's standard library.
`pubspec.yaml` declares the Dart packages, and `pubspec.lock` records the
resolved versions. QUL and Tanzil are data sources with their own attribution
and usage terms.
