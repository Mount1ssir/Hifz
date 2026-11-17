# Quran Memorization App: Development Roadmap

*Prepared with Claude · 16 November 2026*

## Overview

This is an 11–12 week plan for the Hifz and Muraja’ah app, assuming a solo developer working roughly 10–15 hours a week and shipping Android first. The Google Play testing gate takes fixed calendar time, so it starts early and runs alongside development.

| Phase | Weeks | You end with |
| --- | --- | --- |
| 0. Foundations | 1 | Running skeleton, CI, decisions written down |
| 1. Quran data layer | 2–3 | Verified Quran database bundled in the app |
| 2. Domain algorithms | 3–4 | Tested Hifz planner and revision partitioner |
| 3. MVP screens | 5–7 | Both modules working end to end |
| 4. Reminders and polish | 8 | Release candidate |
| 5. Closed test and launch | 5–11 | Live on Google Play |
| 6+. Extensions | After v1.0 | Streaks, audio, smart revision, sync, iOS |

## Phase 0: Foundations (week 1)

- Create the repo with the feature-module folder layout (`core/`, `domain/`, `features/`, `app_modules.dart`), strict lints, and GitHub Actions running `flutter analyze` and `flutter test` on every push.
- Add a CI check that fails if anything in `lib/domain/` imports `package:flutter`. It’s the cheapest way to keep the algorithms pure.
- Write a one-page decision log covering:
  - how the Basmalah is stored (it’s a numbered verse only in Al-Fatiha);
  - quota units (verses, lines, pages);
  - memorization direction and rest days;
  - what a missed day does (shift the schedule or redistribute).
- Treat `Riwayah` as a parameter in the data layer now, even though only Hafs ships. Verse counts and numbering can differ between riwayat, so use `riwayah.totalAyahs` instead of a hardcoded `6236`.

**Done when:** a blank app runs on your phone and CI is green.

## Phase 1: Quran data layer (weeks 2–3)

- Write a one-off import script (Tanzil text and metadata) that outputs a pre-seeded SQLite file. Keep the text byte-identical to the source, since Tanzil’s terms require it unmodified plus attribution. Add a checksum test so it can’t change by accident.
- Use two databases: a read-only bundled `quran.db`, and a Drift-managed `user.db` for progress. Progress points to verses by ayah ID only, so you can ship corrected Quran data without migrating user data.
- For line-based quotas you need line data. QUL (Tarteel’s Quranic Universal Library) offers 604-page, 15-line Hafs mushaf layouts as downloadable SQLite or JSON, and each line record carries first and last word IDs. Join that with a word-level script package to derive how many lines each verse takes. Check each resource’s license before bundling it.
- Add sanity tests: 114 surahs, 6,236 verses, per-surah counts matching a reference table, pages running 1–604 in order, juz boundaries lining up.

**Done when:** the invariant tests pass and the database opens fast on a low-end phone.

## Phase 2: Domain algorithms (weeks 3–4)

Pure Dart, tests first.

- Build `RangeSet` first, with merge, subtract, complement, and length over ayah ID ranges. Both modules sit on it.
- Build `HifzPlanner` behind a strategy interface.
  - Remaining text is the complement of the baseline, so non-contiguous baselines work (a single “next ayah” pointer only handles one contiguous run).
  - Support forward, backward, and custom order.
  - For line or page quotas, fill greedily and never split a verse.
- Build `RevisionPartitioner`: weight each verse (words or lines) and cut where the running total first reaches k × total ÷ N. Each chunk stays within the heaviest verse’s weight of total ÷ N.
- Test these edge cases: empty baseline, whole Quran memorized, quota larger than what’s left, more days than verses, one day, short last session. Also check that the chunks’ union equals the memorized set with no overlaps.

**Done when:** `domain/` has 90%+ coverage, and someone who has memorized portions has sanity-checked a few generated plans.

## Phase 3: MVP screens (weeks 5–7)

- **Week 5:** onboarding (surah checklist plus partial-surah ayah range, daily quota, a live “you’ll finish on \[date\]” preview), then the Hifz screen with the syllabus and a Today card. Push a Hifz-only build to closed testing at the end of the week.
- **Week 6:** the Muraja’ah screen (pick days, preview the partition, today’s portion, mark done) and a minimal reader showing the session’s text in the KFGQPC Hafs font.
- **Week 7:** settings, edit-baseline-and-recompute, Arabic and English localization (ARB files), RTL checks, dark mode, and large-font support.
- Persist inputs and completion logs, not generated plans. A plan is a pure function of its inputs, so it never goes stale when you improve the algorithm.

**Done when:** you’ve used it for your own daily hifz for a full week.

## Phase 4: Reminders and polish (week 8)

- Add daily reminders with `flutter_local_notifications`. Android 13+ requires a runtime notification permission, and Android 14+ doesn’t grant the exact-alarm permission by default, so ask for the first at a sensible moment and schedule reminders as inexact. Also declare the boot permission so alarms survive reboots.
- Write one `integration_test` for the happy path: onboard, see the plan, complete a session.
- Use crash reporting only (Crashlytics or Sentry’s free tier) and no analytics in v1, so the privacy policy can say progress never leaves the device.
- Add an attributions screen: text source, font, QUL data, open-source licenses.
- Test on small screens, an older Android version, and large font scales.

**Done when:** you’ve tagged a release candidate.

## Phase 5: Closed test and launch (weeks 5–11)

- Open the Play Console account in week 4 or 5. The registration fee is a one-time $25, payable by credit or debit card; prepaid cards aren’t accepted. Google is also phasing in Android developer verification, with global enforcement planned for 2027, so check the Play Console home page for your app’s registration status before launch.
- Know the testing gate: personal accounts created after 13 November 2023 must run a closed test with at least 12 testers opted in continuously for 14 days before they can publish to production. Older personal accounts and organization accounts are exempt, though an organization account needs a D-U-N-S number, which can take up to 30 days to obtain.
- Recruit more than 12 (aim for about 20), because most failed attempts come from testers dropping out, and testers have to actually use the app, not just install it. Ask them to follow a daily plan for the two weeks. Hifz circles, teachers, and friends are a natural pool.
- Internal testing (up to 100 testers, no review) is useful for your own iteration but doesn’t count toward the requirement.
- After the 14 days, expect roughly two days for Google’s decision on your production application, then up to seven days of review.
- Draft the privacy policy (GitHub Pages hosts it free), data-safety answers, and Arabic and English screenshots early. You’ll need them before production at the latest.

**Done when:** v1.0 is live. Android total cost: $25.

## Phase 6+: After v1.0

- **v1.1, habit loop:** build the module registry and event bus first (the third feature is the trigger for introducing them), then streaks, stats, and missed-day catch-up.
- **v1.2, listening:** `just_audio`, verse repeat and loop, reciter downloads. QUL offers recitation audio with ayah-level timestamp data, which supports looping and highlighting. Check each reciter’s license.
- **v1.3, smarter revision:** Sabaq/Sabqi/Manzil tiers (new lesson, recent revision, older portions), self-rated strength per portion, spaced repetition, and a hide-the-text self-test mode. This needs the completion history from v1.1.
- **v2.0, backup and sync:** JSON export/import first, then accounts and cloud sync behind the repository interfaces, once people ask for multi-device.
- **v2.x, reach:** iOS (Apple’s developer program is $99 a year, and builds need macOS), more riwayat, home-screen widgets, and teacher/student mode.

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
