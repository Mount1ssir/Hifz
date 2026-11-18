# Quran data

Run `python3 tool/import_quran.py` to rebuild the bundled database offline
from the pinned sources in `data/sources/`. The manifest records download URLs
and SHA-256 hashes. Run `python3 tool/verify_quran.py` to verify source and bundle
checksums, exact verse bytes, per-surah counts, page and juz boundaries.

The text comes from Tanzil Uthmani 1.1. Its full notice is preserved in the
source, database metadata, and bundled TANZIL-NOTICE.txt. The metadata XML
identifies its copyright and CC-BY license. [Tanzil downloads](https://tanzil.net/download/)

The export includes opening Basmalahs in the first ayah's text. We retain
that text intact and record the exact prefix separately for future reader
presentation. Surah 95 uses a different initial diacritic, also preserved.
Page and juz values identify the partition containing the ayah's start.

Startup copies the checksum-addressed bundle atomically into application
support storage and opens it read-only. Drift opens a separate user.db.
Progress keys include riwayah, numbering identity, and ayah ID. Updating Quran
text therefore leaves progress intact. Regenerate Drift code after schema
edits with `dart run build_runner build`.

The selected QUL V1 layout and matching word script both report unavailable
copyright information. Their license verification and line-span import remain
pending. Line weights are unavailable until that data is cleared and imported.
[Layout license](https://qul.tarteel.ai/resources/mushaf-layout/15/licence),
[word-script license](https://qul.tarteel.ai/resources/quran-script/57/licence).

The initial performance target is at most 500 ms for a warm database open and
2 seconds for first installation on a low-end Android phone. Startup logs
`Hifz database open: N ms`, including asset verification and both database opens.
Record the device, OS, build mode, and five warm measurements plus a first-run
measurement. Physical-device measurement is still pending.

## Collect phone measurements

With the Phase 1 debug APK installed and the phone connected and authorized,
run these commands from the project root:

```sh
source .hifz-env/activate
python3 tool/benchmark_android.py
```

The tool performs one preparation launch and five measured process restarts.
It preserves app data and saves device details and results to
`build/database-timing.json`. With multiple devices, pass `--serial DEVICE_ID`.
These are debug-build results. First-install timing requires a separate fresh
installation measurement, and the recorded model must be assessed against the
low-end device target.

The [licensing question](qul-license-request.md) is ready to submit to QUL.
Record their response and applicable terms before marking the licensing item
complete.
