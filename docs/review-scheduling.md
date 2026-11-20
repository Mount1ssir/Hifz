# Intraday recall scheduling

The implementation uses a Leitner-inspired learning sequence. Ratings change
the next gap. The initial sequence is 10, 60, and 240 minutes after memorization
completion or the preceding review. After Again the next gap is one quarter
of its configured value; Hard halves it, Good retains it, and Easy multiplies
it by 1.5. Minute values round upward. These minute intervals and factors are
provisional product choices requiring a Quran-learning pilot.

Spacing and active recall have experimental support. The optimal spacing
depends on the retention period, and the original SM-2 algorithm uses day-based
intervals. Our intraday adaptation needs its own evaluation through delayed
unaided recall and learner feedback. [Spacing research](https://pubmed.ncbi.nlm.nih.gov/19076480/),
[retrieval practice research](https://learninglab.psych.purdue.edu/downloads/2007/2007_Karpicke_Roediger_JML.pdf),
[original SM-2 specification](https://super-memory.com/english/ol/sm2.htm).

Learners can configure one to eight gaps of 1–1440 minutes in Review → Review
rhythm. Turning adaptation off makes the configured gaps apply exactly.
Changing settings recomputes future reviews while retaining all attempts.
Reducing the count below the completed count ends the remaining schedule.
Increasing it adds reviews to the same portion.

Completion creates one session per riwayah and local calendar day, with a
snapshot of the ayah IDs. Review attempts are append-only by session and ordinal.
Saving a duplicate ordinal has no effect. A transaction checks that the next
review is due before saving its rating and timestamp. Memorization completion
and recall attempts are stored separately. The schema upgrade preserves prior
progress. Existing review sessions and completion history remain preserved. A baseline
revision invalidates the currently displayed completed portion, and completion
of its replacement gets a distinct session identity even on the same day.

An overdue review remains due across midnight. Later preview times account for
the overdue review being completed no earlier than now, preventing a queue of
immediately overdue predictions. Actual later due times are derived from saved
completion timestamps. Instants are stored and calculated in UTC and displayed
in local time, so changing time zones preserves elapsed spacing. The session's
original day identity and ayah snapshot remain fixed. New daily memorization
continues independently of outstanding review sessions.

The Review tab shows due times, estimated later times, and completed ratings.
A due session opens with hidden text, then allows reveal and self-rating.
The dashboard refreshes while open and after returning from the background.
The broader Muraja’ah partition interface remains a later roadmap task.


## Android reminders (20 November 2026)

Learners can choose 1–8 sessions distributed over 1–24 hours after completing
memorization, or keep custom minute gaps. A preview is shown before saving.
Adaptive ratings continue to update subsequent times through the existing
scheduler. Reminder times use UTC instants and local times for display.

`flutter_local_notifications` 19.5 is compatible with the project's Android
SDK. Notifications are scheduled with `inexactAllowWhileIdle`: Android may delay
delivery to conserve battery. Enabling notifications requests the Android
permission; denial is shown in Arabic without losing saved review settings.
The boot/app-update receiver restores plugin-persisted schedules. On resume,
settings changes, portion completion, and recall completion, schedules are
reconciled. Overdue reviews remain visible with a red badge without generating
repeated immediate alerts each time the app opens. Notification taps open
consolidation. The badge refers to due reviews, not an OEM-specific launcher badge.

Source: [plugin setup and scheduling documentation](https://pub.dev/packages/flutter_local_notifications/versions/19.5.0).
The automated check covers Android scheduling calls and cancellation. Physical
notification delivery, reboot behavior, and battery restrictions still need a
phone check; these are not claimed as verified.
