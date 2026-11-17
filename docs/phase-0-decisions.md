# Phase 0 design decisions

Recorded 17 November 2026. These decisions guide the MVP implementation.
Product defaults are initial choices and remain editable as the app develops.

## Quran text and Basmalah

Use the selected Tanzil Hafs dataset's numbering and preserve source text
byte-for-byte. Store numbered ayahs with their surah number, ayah number, and
dataset-local sequential ID. The opening Basmalah in Al-Fatiha is ayah 1:1.
Other opening Basmalahs have separate, unnumbered presentation metadata, with
no opening Basmalah for surah 9. They receive no extra ayah ID or verse quota.
Preserve any Basmalah within a numbered ayah as part of that ayah's source text.
The importer must inspect the chosen export's treatment of opening Basmalahs
and avoid duplicating them in the reader. [Tanzil's numbering note](https://tanzil.net/docs/a_note_on_bismillah)

## Riwayah and identity

Require an explicit `Riwayah` when opening a Quran repository and generating
plans. Ship Hafs first. Read bounds from `riwayah.totalAyahs` and validate them
against imported metadata. Qualify persisted ayah references by riwayah and
dataset numbering identity so future datasets cannot reinterpret progress.
Keep layout identity with line and page metadata. Domain algorithms accept
numeric ranges and weights without importing Flutter or database code.

## Daily quotas

Accept a positive integer number of ayahs, lines, or pages. An ayah quota
counts whole numbered ayahs. For line quotas, an ayah's weight is the count
of distinct mushaf lines touched by its words, using the selected layout.
Shared lines count toward each touching ayah, so this is an approximate
reading workload. A page quota equals 15 line units for the selected 15-line
Hafs layout. Derive this conversion from layout metadata.

Select the next whole ayahs in the chosen order until the cumulative weight
meets or exceeds the quota, or the remaining set is exhausted. Include a
single ayah even if its weight exceeds the quota. Display the actual assigned
range and workload, including any overshoot. A final session may be shorter.

## Direction and rest days

Default to forward canonical order. Backward order selects from the end of
the remaining ayah set, while the reader presents each selected contiguous
range in canonical recitation order. Custom order is an ordered list of ayah
ranges, with first occurrence winning for overlaps. Show omitted remaining
ayahs and require a complete order before projecting a full-Quran finish date.

Let learners select active weekdays, with all seven active by default.
Require at least one active day. Rest days receive no new Hifz assignment.
Muraja’ah and intraday consolidation retain their own schedules and settings.
Calculate dates in the learner's local time zone.

## Missed days and consolidation

Shift unfinished memorization work to the next active day and recompute the
remaining syllabus from recorded completion. Preserve completed work and
keep the daily quota fixed. For example, missing Tuesday moves its unfinished
portion to Wednesday when Wednesday is active, pushing later work forward.
Show the resulting finish-date change.

Treat daily memorization completion and individual recall attempts as distinct
events. The intraday scheduler consumes the assigned ayahs, timestamps, ratings,
and learner settings. Its algorithm, late-review policy, and custom-interval
precedence are Phase 2 decisions. Persist these inputs and events so schedules
can be regenerated and completed attempts retained after restarts or edits.
