# Quran Memorization App Development Roadmap

_16 November 2026 · Checklist updated 17 November 2026_

## Overview

Check a task after its stated result is verified. Check a phase's completion gate
only after all required tasks and the gate itself are verified.

| Phase                     | Target weeks | Deliverable                                            |
| ------------------------- | ------------ | ------------------------------------------------------ |
| 0. Foundations            | 1            | Flutter skeleton, CI, and design decisions             |
| 1. Quran data layer       | 2–3          | Verified bundled Quran database                        |
| 2. Domain algorithms      | 3–4          | Tested Hifz, Muraja’ah, and intraday review schedulers |
| 3. MVP screens            | 5–7          | Hifz, daily consolidation, and Muraja’ah flows         |
| 4. Reminders and polish   | 8            | Release candidate                                      |
| 5. Closed test and launch | 5–11         | Android v1.0 on Google Play                            |
| 6+. Extensions            | After v1.0   | Streaks, audio, smarter revision, sync, and iOS        |

## Phase 0 — Foundations (week 1)

- [x] Initialize and commit the Android-first Flutter scaffold (`70e59af`).
- [x] Install Flutter 3.50.0, Dart 3.14.0, and the Android API 36 build toolchain locally.
- [x] Create `lib/core/`, `lib/domain/`, `lib/features/`, and `lib/app_modules.dart`.
- [x] Enable strict Dart analyzer settings and Flutter lints.
- [x] Add a GitHub Actions workflow for formatting, analysis, and tests on pushes and pull requests.
- [x] Add and locally verify the CI check that rejects Flutter imports in `lib/domain/`.
- [x] Pass local formatting, static analysis, and the starter-screen smoke test.
- [x] Build and inspect the Android debug APK.
- [x] Record the Phase 0 design decisions in a [one-page log](docs/phase-0-decisions.md).
  - [x] Document Basmalah storage and verse numbering for the Hafs dataset.
  - [x] Define verse, line, and page quota semantics.
  - [x] Define memorization directions and rest days.
  - [x] Decide whether a missed memorization day shifts or redistributes the syllabus.
- [x] Record that the data layer accepts a `Riwayah` parameter and reads verse counts from `riwayah.totalAyahs`.
- [x] Launch the starter app on a physical Android phone.
- [x] Confirm the GitHub Actions workflow passes on a pushed commit.
- [x] **Phase complete** — The starter app runs on a phone, hosted CI is green, and the design decisions are recorded.

## Phase 1 — Quran data layer (weeks 2–3)

- [x] Write a repeatable Tanzil text and metadata import script that generates `quran.db`.
  - [x] Preserve the imported Quran text byte-for-byte and include Tanzil attribution.
  - [x] Add a checksum test for the imported text.
- [x] Bundle and open `quran.db` read-only.
- [x] Set up Drift-managed `user.db` for progress, with ayah IDs as references to Quran text.
- [x] Parameterize Quran data access by `Riwayah`, ship Hafs first, and use `riwayah.totalAyahs` for dataset bounds.
- [ ] Add the Hafs mushaf data needed for line and page quotas.
  - [x] Import Tanzil page boundaries.
  - [x] Inspect the QUL V1 layout and matching word-script license pages. Both report unavailable copyright information, so clearance and import remain pending.
  - [x] Prepare a [licensing question for QUL](docs/qul-license-request.md).
  - [ ] Verify the licenses for the QUL layout and word-level script before bundling.
  - [ ] Join the 604-page, 15-line layout's word ranges against the word-level script to compute verse line spans.
- [x] Add and pass dataset invariant tests.
  - [x] Verify 114 surahs and 6,236 verses for the selected Hafs dataset.
  - [x] Match per-surah verse counts against a reference table.
  - [x] Verify page order and coverage from 1 through 604.
  - [x] Match juz boundaries against reference metadata.
- [ ] Measure database opening on a low-end Android phone.
  - [x] Set targets of 500 ms warm and 2 seconds on first installation, with startup timing instrumentation.
  - [x] Add a repeatable Android timing tool that preserves app data.
  - [ ] Connect and authorize the phone, collect timings, and record device details.
- [ ] **Phase complete** — All data invariants pass and the bundled database meets the open-time target.

Phone startup has been confirmed by the user. Performance is assumed sufficient
for continued development at the user’s request; measured timing remains pending.
QUL licensing and layout import remain open while independent work proceeds.

## Phase 2 — Domain algorithms (weeks 3–4)

Implement the algorithms in pure Dart and write their tests before implementation.

- [x] Implement and test `RangeSet` operations for merge, subtract, complement, and length over ayah ID ranges.
- [x] Implement and test `HifzPlanner` behind a strategy interface.
  - [x] Derive remaining ayahs from the complement of the baseline, including non-contiguous baselines.
  - [x] Support forward, backward, and custom order.
  - [x] Fill line and page quotas greedily while keeping verses whole. Verified with synthetic weights; real layout weights await the QUL import.
  - [x] Cover empty and fully memorized baselines, oversized quotas, and a short final session.
- [x] Implement and test `RevisionPartitioner`.
  - [x] Weight ayahs by words or lines and place cuts near each multiple of total weight divided by the number of days.
  - [x] Check chunk weight against the heaviest-verse tolerance and verify complete, non-overlapping coverage of memorized ayahs.
  - [x] Cover one revision day and more revision days than ayahs.
- [ ] Implement an intraday SRS scheduler for the ayahs assigned by `HifzPlanner`.
  - [ ] Select and document an empirically supported scheduling approach, such as a forgetting-curve model, Leitner-style progression, or an adaptation of SM-2. Record the evidence for the approach, any assumptions in adapting it to same-day Quran recall, and how the adaptation will be validated.
  - [ ] Generate review due times from the daily assignment and recall outcomes. Define when weaker recall brings the next review forward and when stronger recall allows a longer interval.
  - [ ] Support learner-defined repetitions per day and intervals between repetitions. Define how settings override or constrain the adaptive schedule and how invalid settings are handled.
  - [ ] Define behavior for late or missed reviews, setting changes, day rollover, and time-zone changes. Preserve completed attempts and avoid duplicate due reviews.
  - [ ] Test default and customized schedules with a controllable clock, including weak and strong recall, interval changes, and day rollover.
- [ ] Measure at least 90% test coverage for `lib/domain/` after the SRS scheduler is implemented. Current range and planning implementation has 99.1% line coverage (108/109).
- [ ] Have someone with Quran memorization experience review sample Hifz, Muraja’ah, and intraday schedules.
- [ ] **Phase complete** — Domain tests pass, coverage meets the target, and sample schedules have been reviewed.

## Phase 3 — MVP screens (weeks 5–7)

### Week 5 — Onboarding and Hifz

- [ ] Build onboarding with a surah checklist, partial-surah ayah ranges, daily quota, and a live projected finish date.
- [ ] Build the Hifz screen with a syllabus and a Today card that opens the daily assignment.
- [ ] Submit the Hifz-only build to closed testing at the end of week 5, subject to Play Console readiness.

### Week 6 — Daily Memorization & Consolidation Interface and Muraja’ah

The Daily Memorization & Consolidation Interface shall use Spaced Repetition
Systems (SRS) and Active Recall to counter forgetting and support long-term
retention and memory consolidation. It shall schedule intraday reviews of the
daily assigned curriculum using the evidence-based scheduler from Phase 2.
Learners shall be able to adjust repetition frequency and time intervals for
their own cognitive load and recall performance.

- [ ] Build the dedicated interface and open it from the Hifz Today card.
  - [ ] Show the assigned ayah ranges and the schedule of due, upcoming, and completed reviews.
  - [ ] Prompt the learner to recite from memory with the assigned text hidden, then reveal the text for comparison and collect a recall rating.
  - [ ] Feed the rating into the scheduler and show the updated next review time.
  - [ ] Let the learner set the daily repetition count and intervals, preview the resulting schedule, and save or reset the settings.
  - [ ] Verify that the interface reflects the default schedule, a customized schedule, and a schedule updated after a weak recall attempt.
- [ ] Build the Muraja’ah screen with revision-day selection, a partition preview, today's portion, and a completion action.
- [ ] Build a minimal reader for session text using the KFGQPC Hafs font.

### Week 7 — Settings, persistence, and accessibility

- [ ] Add settings and let learners edit their baseline and recompute their plan.
- [ ] Persist planning inputs, review settings, recall attempts, and completion logs. Derive schedules from those inputs and logs.
- [ ] Verify after restarting the app that settings, attempts, completed reviews, and the next due review are restored.
- [ ] Localize the MVP in Arabic and English using ARB files and verify RTL layout.
- [ ] Verify dark mode and large font scales.
- [ ] **Phase complete** — Use Hifz, active recall, and intraday reviews for one week and verify that Muraja’ah works from schedule setup through completion.

## Phase 4 — Reminders and polish (week 8)

- [ ] Add daily Hifz reminders and reminders for upcoming intraday reviews with `flutter_local_notifications`.
  - [ ] Request notification permission where required, schedule inexact reminders, and restore pending reminders after reboot.
  - [ ] Verify that settings or due-time changes replace obsolete reminders and that completing a review cancels its pending reminder.
- [ ] Add an `integration_test` that onboards a learner, opens the assigned portion, completes an active recall review, and shows the next review time.
- [ ] Configure Crashlytics or Sentry for crash reporting and verify that analytics are disabled and Quran progress stays on-device.
- [ ] Add attributions for Quran text, font, QUL data, and open-source licenses.
- [ ] Test a small screen, an older supported Android version, and large font scales.
- [ ] Compare delayed unaided recall under the proposed default schedule with a baseline schedule in a pilot. Document the interval settings, recall measure, results, and limits before making retention claims.
- [ ] **Phase complete** — Tag a release candidate after verification passes.

## Phase 5 — Closed test and launch (weeks 5–11)

- [ ] Open the Play Console account in week 4 or 5 and confirm the current fee, payment options, and developer verification requirements.
- [ ] Confirm the account-specific production testing requirements. Use 12 continuous opt-ins for 14 days as the planning target if that gate applies.
- [ ] Recruit around 20 testers through Hifz circles, teachers, and friends. Ask them to follow a daily plan during the closed test.
- [ ] Run an internal test for early feedback if needed.
- [ ] Run the closed test and verify that the applicable opt-in and testing requirements are met.
- [ ] Prepare the Play Store materials.
  - [ ] Publish the privacy policy and complete the data-safety answers.
  - [ ] Capture Arabic and English screenshots.
  - [ ] Assign a permanent Android application ID and configure release signing.
- [ ] Apply for production access if required, then submit the release for review.
- [ ] **Phase complete** — Verify that Android v1.0 is live on Google Play.

## Phase 6+ — After v1.0

- [ ] **v1.1 — Habit loop**
  - [ ] Add the module registry and event bus when introducing the third standalone feature module.
  - [ ] Add streaks, statistics, and missed-day catch-up.
- [ ] **v1.2 — Listening**
  - [ ] Verify reciter and QUL audio licenses before bundling or offering downloads.
  - [ ] Add playback, ayah-level looping and highlighting, and reciter downloads with `just_audio`.
- [ ] **v1.3 — Smarter Muraja’ah**
  - [ ] Add Sabaq, Sabqi, and Manzil tiers using the completion history from v1.1.
  - [ ] Add self-rated strength and multi-day SRS for previously memorized portions.
  - [ ] Reuse the MVP's hidden-text recall flow for Muraja’ah self-tests.
- [ ] **v2.0 — Backup and sync**
  - [ ] Add JSON export and import.
  - [ ] Add accounts and cloud sync behind repository interfaces when multi-device demand is established.
- [ ] **v2.x — Reach**
  - [ ] Set up macOS builds and verify Apple Developer Program requirements for iOS.
  - [ ] Add more riwayat.
  - [ ] Add home-screen widgets.
  - [ ] Add teacher and student mode.

## Sources

Fees, store requirements, and platform behavior change, so re-check these before you act on them.

- Google Play Console Help, testing requirements for new personal accounts: https://support.google.com/googleplay/android-developer/answer/14151465
- Closed-testing details (organization accounts, internal testing, review timing, tester attrition): https://www.choicely.com/blog/google-play-12-tester-rule, https://www.testerscommunity.com/research/the-12-tester-era, https://www.testerscommunity.com/blog/google-play-closed-testing-requirements-2026, https://extendsclass.com/blog/google-plays-closed-testing-requirement-what-developers-need-to-know-in-2026
- Play registration fee: https://newly.app/guides/cost-to-publish-an-app
- Apple Developer Program fee: https://www.choicely.com/tutorials/how-much-does-it-cost-to-publish-an-app
- Android developer verification: https://developer.android.com/developer-verification/guides and https://android-developers.googleblog.com/2026/06/android-developer-verification.html
- QUL mushaf layouts and tutorial: https://qul.tarteel.ai/mushaf\_layouts and https://qul.tarteel.ai/docs/tutorial-mushaf-layout-end-to-end
- QUL recitation resources: https://qul.tarteel.ai/resources
- Android notification permissions and exact alarms in Flutter: https://dev.to/mxomasuku/build-reliable-local-notifications-in-flutter-step-by-step-3l1f and https://github.com/MaikuB/flutter\_local\_notifications/issues/1906

- Original research on the relationship between review spacing and delayed retention. [Cepeda et al., 2008](https://pubmed.ncbi.nlm.nih.gov/19076480/)
- Original research on the effect of retrieval practice on later retention. [Karpicke and Roediger, 2007](https://learninglab.psych.purdue.edu/downloads/2007/2007_Karpicke_Roediger_JML.pdf)
- Background on the original SM-2 algorithm and its design. [SuperMemo](https://www.supermemo.com/en/blog/the-true-history-of-spaced-repetition)
