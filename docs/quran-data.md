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

The supplied QUL archives are pinned in `data/sources/` with SHA-256 hashes.
The importer joins 83,668 word IDs to the V1 printed line ranges and stores
13,766 distinct `(ayah_id, page, line)` records in `ayah_lines`. It rejects missing
words, duplicate assignments, invalid line coordinates, and incomplete coverage.
The bundle covers all 6,236 ayahs and 604 printed pages. QUL glyph text is used
only to identify word records; the rendered text remains the original Tanzil text.

The planner counts distinct printed lines touched by each ayah. Shared lines
count for each touching ayah, matching the Phase 0 workload decision. A page
quota uses 15 line units. Portions stop after reaching the requested workload,
keeping the final ayah whole. These values measure approximate reading workload.
The app's quota dialog offers ayahs, lines, and pages and saves both the amount
and unit atomically. Existing settings retain their ayah unit.

Only the generated database, checksum, and attribution files are Flutter assets.
The original uploaded archives remain in `assets/data/`, while reproducible
imports use the pinned copies in `data/sources/`.
On 18 November 2026 the user reported that QUL’s platform and email confirmed
use of these developer resources. The confirmation is user-reported; the email
is not archived in this repository.
[Layout source](https://qul.tarteel.ai/resources/mushaf-layout/15),
[word source](https://qul.tarteel.ai/resources/quran-script/57).

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

The user reports receiving usage confirmation from QUL. The earlier
[licensing question](qul-license-request.md) is retained as background.
