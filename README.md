# Hifz

An Android-first Quran app with offline printed pages, memorization (Hifz),
and revision (Muraja’ah). See the [development roadmap](Quran%20Memorization%20App%20Development%20Roadmap.md)
for completed work and the remaining features.

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

## How Hifz is organized and what its dependencies do

Hifz is a Quran app with memorization and revision features, written in Flutter/Dart.
It opens on the complete offline Quran: 604 printed pages, a surah/juz index,
page navigation, bookmarks, and a saved reading position. The Memorize tab offers
daily ayah/line/page quotas, a syllabus, saved progress, and page-based hide/reveal
practice. Review schedules spaced recall with self-ratings and custom intervals.
Card mode has been removed. Onboarding, colored tajweed, audio, translation,
and verse search remain roadmap tasks.

### The architecture

| Part | Location | Responsibility |
| --- | --- | --- |
| Startup | `lib/main.dart` | Initialize Flutter, register text attribution, and open the databases before showing the app. |
| App and screens | `lib/app_modules.dart`, `lib/features/` | Present information and handle learner actions. Feature screens will call the planning and storage layers. |
| Domain logic | `lib/domain/` | Calculate memorization ranges, daily portions, and revision partitions using pure Dart. These calculations can be tested without a phone. |
| Storage | `lib/core/data/` | Read Quran data and save learner progress. |
| Import tools | `tool/`, `data/sources/` | Turn pinned source downloads into a verified database before the app is built. |
| Bundled assets | `assets/data/`, `assets/quran_fonts/` | Ship Quran data and its attribution with the app for offline use. |

There are two SQLite databases. `quran.db` contains the Quran text and structural
metadata and is opened read-only. `user.db` stores the learner's progress.
A progress entry references an ayah by its ID, riwayah, and numbering identity.
This lets us update the bundled text database while retaining saved progress.

For example, the Today screen loads the learner's memorized ayahs from
`user.db`, pass them and the daily quota to `HifzPlanner`, then reads the assigned
ayah text from `quran.db`. Completing the portion saves progress in `user.db`.

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

The supplied QUL layout and word files are now imported. The daily quota dialog
supports ayahs, printed-line workload, and page workload. Line weights count
the distinct printed lines touched by each ayah; a shared line contributes to
each touching ayah. A page is 15 line units, and portions keep ayahs whole.
The import runs during development, and the app reads the bundled results
offline. QUL source archives and hashes are retained for reproducibility.
The user reports that QUL’s platform and email confirmed use of its developer
resources. This confirmation is recorded in the project notes.
[Layout resource](https://qul.tarteel.ai/resources/mushaf-layout/15),
[word-script resource](https://qul.tarteel.ai/resources/quran-script/57).

QUL also supplies the **printed page appearance**. The app combines its word glyph
codes, line positions, and 604 matching V1 fonts to draw the Quran without reflowing
the printed lines. Fonts load one page at a time from bundled files; reading needs
no internet. Tanzil's original searchable text stays intact in the database.
This V1 rendering is monochrome. Matching the reference's colored tajweed requires
a compatible tajweed font and word dataset, tracked separately in the roadmap.
[Page font resource](https://qul.tarteel.ai/resources/font/238).

To restore the font assets during development, run
`python3 tool/fetch_quran_fonts.py` (requires internet and `curl`). The download
checks the pinned font hashes; `python3 tool/verify_quran.py` verifies the complete
offline bundle.

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


### Set up your memorization

In **Memorize / الحفظ**, today’s Quran portion opens directly. The single gear
button opens daily quota, Arabic syllabus, review access, and **محفوظي السابق**
(previous memorization). Select entire
surahs or use their edit button to enter verse ranges, such as `1-20, 30-40`.
Save to recalculate the plan from the first unmemorized verse; known passages
anywhere else in the Quran are skipped too. Existing completed sessions remain
saved, and importing past memorization does not complete today's review.

The quota accepts typed amounts in ayahs, lines, pages, or half-pages. Choose
**نصف صفحة** with amount `1`, or pages with `0.5`, for a half-page target.
Printed-line workload keeps verses whole and may exceed the target. Completed
portions appear green with checkmarks in the Arabic syllabus. الحفظ shows only the assigned verses. التثبيت opens today’s portion hidden, with the preceding verse visible as a cue. The arrows reveal and hide assigned words.

Use the eye control to hide the assigned text. The word arrows reveal the next
word or hide the previous word in its original position; each page retains its
own reveal progress for the current session. Swipe horizontally to change pages; the remaining arrows are only for word reveal.
Tap the Quran page to hide the app header, footer, and tab bar; tap again or use
Back to restore them. This works in the full Quran and memorization readers.
After completing today’s portion, **مراجعة ورد اليوم** opens its consolidation
schedule. The review interval editor previews the selected gaps before saving;
adaptive recall outcomes may change those times.


Reader text keeps the same size when controls are hidden, shown, or switched to
word-by-word practice. Compact controls animate in and out without changing the
font size. Tap the Quran header’s surah name to choose another surah, juz, saved
page, or page number. Page totals and page-switching arrows have been removed;
the footer shows only the current page number. A green tick beside **Assigned**
indicates a completed Hifz portion. The daily-quota settings also show a live
finish-date estimate, assuming one portion every day without rest days.


### تحديث ٢٠ نوفمبر: المحفوظ والتذكيرات

الواجهة الآن بالعربية، وقائمة القرآن تتضمن **الإعدادات**. لتعديل المحفوظ،
افتح **محفوظي السابق** واختر السورة، ثم حرّك حدّي النطاق أو أدخل أول آية
وآخر آية بدقة. تظهر معاينة الآيتين، ويمكن إضافة نطاقات متعددة أو إزالة نطاق.
اضغط **تطبيق** ثم **حفظ**. تعديل المحفوظ يعيد اختيار الورد التالي؛ لا يعرض
الورد القديم المكتمل بدلًا منه، ولا يحذف سجل التثبيت السابق.

في **التثبيت ← إعداد جلسات التثبيت**، أدخل عدد الجلسات والمدة التي تريد
توزيعها خلالها، أو اختر الفواصل المخصصة. فعّل **إرسال إشعار لكل جلسة** ثم
اسمح بالإشعارات عندما يطلب الهاتف ذلك. تبدأ المواعيد من إتمام الورد وتتحدث
بعد التقييم. العلامة الحمراء تعني وجود جلسة مستحقة. قد يؤخر أندرويد التنبيهات
قليلًا لتوفير الطاقة. يمكنك إيقافها من **زر القائمة في القرآن**.

أضيفت حزمة `flutter_local_notifications` للتنبيهات المحلية و`timezone` لحفظ
مواعيدها كأوقات ثابتة، مع دعم العربية المرفق بواجهات Flutter. لا تحتاج
التذكيرات إلى خادم أو اتصال بالإنترنت. تُترك نصوص تراخيص المصادر الأصلية
دون ترجمة حفاظًا عليها. لتحسين سلاسة القراءة، تُخزّن بيانات الصفحات وقياسات
الكلمات مؤقتًا وتُحمّل خطوط الصفحات المجاورة مسبقًا. نسخة Android المحسّنة:
`build/app/outputs/flutter-apk/app-release.apk` (موقعة حاليًا بمفتاح التطوير؛
ليست إصدار متجر).


The Quran menu button opens settings directly. Tap the surah name in the header
to choose a surah, juz, bookmark, or page; the selector has no settings button.
UI counts and dates use 0–9 digits while the interface remains Arabic. Original
QUL verse-number glyphs in the printed Quran are preserved.
