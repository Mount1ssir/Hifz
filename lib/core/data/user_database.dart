import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:drift/drift.dart';

import '../../domain/review_scheduler.dart';

import '../../domain/riwayah.dart';
import '../../domain/reading_goal.dart';
import '../../domain/hifz_planner.dart';

part 'user_database.g.dart';

class MemorizedAyahs extends Table {
  TextColumn get riwayah => text()();
  TextColumn get numbering => text()();
  IntColumn get ayahId => integer()();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {riwayah, numbering, ayahId};
}

class Preferences extends Table {
  TextColumn get key => text()();
  IntColumn get value => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class ReviewSessions extends Table {
  TextColumn get id => text()();
  TextColumn get ayahIds => text()();
  DateTimeColumn get startedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ReviewAttempts extends Table {
  TextColumn get sessionId => text().references(ReviewSessions, #id)();
  IntColumn get ordinal => integer()();
  IntColumn get rating => integer()();
  DateTimeColumn get completedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {sessionId, ordinal};
}

@DriftDatabase(
  tables: [MemorizedAyahs, Preferences, ReviewSessions, ReviewAttempts],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(preferences).insert(
        PreferencesCompanion.insert(key: 'hifz_setup_pending', value: 1),
      );
      await _createGoals();
      await _addGoalRanges();
    },
    onUpgrade: (m, from, to) async {
      if (from < 4) await _createGoals();
      if (from < 5) await _addGoalRanges();
      if (from < 2) await m.createTable(preferences);
      if (from < 3) {
        await m.createTable(reviewSessions);
        await m.createTable(reviewAttempts);
      }
    },
  );

  Future<void> _addGoalRanges() =>
      customStatement('ALTER TABLE reading_goals ADD COLUMN recorded TEXT');
  Future<void> _createGoals() async {
    await customStatement(
      'CREATE TABLE reading_goals (id INTEGER PRIMARY KEY, name TEXT NOT NULL, pages INTEGER NOT NULL, anchors TEXT NOT NULL, quota INTEGER NOT NULL, interval_days INTEGER NOT NULL, start_day INTEGER NOT NULL, total INTEGER NOT NULL, read_units INTEGER NOT NULL DEFAULT 0)',
    );
    await customStatement(
      'CREATE TABLE goal_logs (id INTEGER PRIMARY KEY, goal INTEGER NOT NULL REFERENCES reading_goals(id), units INTEGER NOT NULL, logged_at INTEGER NOT NULL)',
    );
  }

  Future<void> createReadingGoal(
    String name,
    bool pages,
    List<int> anchors,
    int quota,
    int interval,
  ) async {
    if (name.trim().isEmpty || anchors.isEmpty || quota < 0 || interval < 1) {
      throw ArgumentError();
    }
    await customStatement(
      'INSERT INTO reading_goals(name,pages,anchors,quota,interval_days,start_day,total) VALUES(?,?,?,?,?,?,?)',
      [
        name.trim(),
        pages ? 1 : 0,
        jsonEncode(anchors),
        quota,
        interval,
        ReadingGoal.day(DateTime.now()),
        anchors.length,
      ],
    );
  }

  Future<List<ReadingGoal>> readingGoals() async =>
      (await customSelect('SELECT * FROM reading_goals ORDER BY id DESC').get())
          .map(
            (r) => ReadingGoal(
              r.read<int>('id'),
              r.read<String>('name'),
              r.read<int>('pages') == 1,
              (jsonDecode(r.read<String>('anchors')) as List).cast<int>(),
              r.read<int>('quota'),
              r.read<int>('interval_days'),
              r.read<int>('start_day'),
              r.read<int>('read_units'),
              r.readNullable<String>('recorded') == null
                  ? null
                  : (jsonDecode(r.read<String>('recorded')) as List)
                        .cast<int>()
                        .toSet(),
            ),
          )
          .toList();

  Future<void> logGoalReading(ReadingGoal goal, int units) async {
    if (units < 1 || units > goal.remaining) throw RangeError.value(units);
    await logGoalRange(
      goal,
      goal.unread.take(units).first,
      goal.unread.take(units).last,
    );
  }

  Future<void> logGoalRange(ReadingGoal goal, int first, int last) =>
      transaction(() async {
        final additions = goal.unread
            .where((id) => id >= first && id <= last)
            .toSet();
        if (additions.isEmpty) throw StateError('Already recorded');
        final units = additions.length;
        final recorded = {
          ...?goal.recorded,
          if (goal.recorded == null) ...goal.anchors.take(goal.read),
          ...additions,
        };
        await customStatement(
          'UPDATE reading_goals SET recorded=?, read_units=read_units+? WHERE id=? AND read_units=? AND read_units+?<=total',
          [jsonEncode(recorded.toList()), units, goal.id, goal.read, units],
        );
        if ((await customSelect(
              'SELECT changes() AS n',
            ).getSingle()).read<int>('n') !=
            1) {
          throw StateError('Stale goal');
        }
        await customStatement(
          'INSERT INTO goal_logs(goal,units,logged_at) VALUES(?,?,?)',
          [goal.id, units, DateTime.now().millisecondsSinceEpoch],
        );
      });

  Future<void> deleteReadingGoal(int id) => transaction(() async {
    await customStatement('DELETE FROM goal_logs WHERE goal=?', [id]);
    await customStatement('DELETE FROM reading_goals WHERE id=?', [id]);
  });

  Future<List<(DateTime, int)>> goalHistory(int id) async =>
      (await customSelect(
            'SELECT logged_at,units FROM goal_logs WHERE goal=? ORDER BY id DESC',
            variables: [Variable.withInt(id)],
          ).get())
          .map(
            (r) => (
              DateTime.fromMillisecondsSinceEpoch(r.read<int>('logged_at')),
              r.read<int>('units'),
            ),
          )
          .toList();

  Future<bool> needsHifzSetup() async =>
      (await (select(
        preferences,
      )..where((p) => p.key.equals('hifz_setup_pending'))).getSingleOrNull()) !=
      null;

  Future<void> finishHifzSetup() async {
    await (delete(
      preferences,
    )..where((p) => p.key.equals('hifz_setup_pending'))).go();
  }

  Future<int> readingPage() async {
    final row = await (select(
      preferences,
    )..where((p) => p.key.equals('reading_page'))).getSingleOrNull();
    return row?.value ?? 1;
  }

  Future<void> saveReadingPage(int page) async {
    RangeError.checkValueInInterval(page, 1, 604, 'page');
    await into(preferences).insertOnConflictUpdate(
      PreferencesCompanion.insert(key: 'reading_page', value: page),
    );
  }

  Future<Set<int>> bookmarks() async =>
      (await (select(
            preferences,
          )..where((p) => p.key.like('bookmark_page_%'))).get())
          .map((row) => row.value)
          .toSet();

  Future<void> setBookmark(int page, bool enabled) async {
    RangeError.checkValueInInterval(page, 1, 604, 'page');
    final key = 'bookmark_page_$page';
    if (enabled) {
      await into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(key: key, value: page),
      );
    } else {
      await (delete(preferences)..where((p) => p.key.equals(key))).go();
    }
  }

  Future<Set<int>> memorizedBaseline(Riwayah riwayah) async =>
      (await (select(
            preferences,
          )..where((p) => p.key.like('baseline_${riwayah.id}_%'))).get())
          .map((row) => row.value)
          .toSet();

  Future<void> saveMemorizedBaseline(Riwayah riwayah, Set<int> ids) async {
    final previous = await memorizedBaseline(riwayah);
    if (ids.length == previous.length && ids.containsAll(previous)) return;
    for (final id in ids) {
      riwayah.validateAyah(id);
    }
    await transaction(() async {
      await into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(
          key: 'baseline_revision_${riwayah.id}',
          value: (await preference('baseline_revision_${riwayah.id}')) + 1,
        ),
      );
      await (delete(
        preferences,
      )..where((p) => p.key.like('baseline_${riwayah.id}_%'))).go();
      await batch(
        (batch) => batch.insertAll(preferences, [
          for (final id in ids)
            PreferencesCompanion.insert(
              key: 'baseline_${riwayah.id}_$id',
              value: id,
            ),
        ]),
      );
    });
  }

  Future<int> preference(String key, {int fallback = 0}) async =>
      (await (select(
        preferences,
      )..where((p) => p.key.equals(key))).getSingleOrNull())?.value ??
      fallback;

  Future<void> setPreference(String key, int value) => into(
    preferences,
  ).insertOnConflictUpdate(PreferencesCompanion.insert(key: key, value: value));

  /// Editing the baseline supersedes today's displayed portion, never its history.
  Future<List<int>> completedToday(Riwayah riwayah, DateTime now) async {
    final baseline = await memorizedBaseline(riwayah);
    final revision = await preference('baseline_revision_${riwayah.id}');
    if (await preference('completion_revision_${riwayah.id}') != revision) {
      return [];
    }
    final active =
        (await (select(preferences)
                  ..where((p) => p.key.like('active_portion_${riwayah.id}_%')))
                .get())
            .map((p) => p.value)
            .toSet();
    return (await progress(riwayah))
        .where((entry) {
          final date = entry.completedAt.toLocal();
          return !baseline.contains(entry.ayahId) &&
              (active.isEmpty || active.contains(entry.ayahId)) &&
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        })
        .map((entry) => entry.ayahId)
        .toList();
  }

  Future<int> dailyQuota() async {
    final row = await (select(
      preferences,
    )..where((row) => row.key.equals('daily_ayah_quota'))).getSingleOrNull();
    return row?.value ?? 5;
  }

  Future<QuotaUnit> dailyQuotaUnit() async {
    final row = await (select(
      preferences,
    )..where((row) => row.key.equals('daily_quota_unit'))).getSingleOrNull();
    final index = row?.value ?? 0;
    if (index < 0 || index >= QuotaUnit.values.length) {
      throw StateError('Unrecognized saved quota unit.');
    }
    return QuotaUnit.values[index];
  }

  Future<void> setDailyQuota(
    int count, {
    QuotaUnit unit = QuotaUnit.ayahs,
  }) async {
    RangeError.checkValueInInterval(count, 1, 100, 'quota');
    await transaction(() async {
      await into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(key: 'daily_ayah_quota', value: count),
      );
      await into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(key: 'daily_quota_unit', value: unit.index),
      );
    });
  }

  Future<void> completePortion(
    Riwayah riwayah,
    Iterable<int> ids,
    DateTime at,
  ) => transaction(() async {
    final ayahs = ids.toSet().toList()..sort();
    if (ayahs.isEmpty) throw ArgumentError('A portion must contain ayahs.');
    for (final id in ayahs) {
      riwayah.validateAyah(id);
    }
    final local = at.toLocal();
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(ayahs)))
        .toString()
        .substring(0, 16);
    final key =
        '${riwayah.id}:${local.year}-${local.month}-${local.day}:$fingerprint';
    final existing = await (select(
      reviewSessions,
    )..where((s) => s.id.equals(key))).getSingleOrNull();
    if (existing != null) return;
    await setPreference(
      'completion_revision_${riwayah.id}',
      await preference('baseline_revision_${riwayah.id}'),
    );
    await (delete(
      preferences,
    )..where((p) => p.key.like('active_portion_${riwayah.id}_%'))).go();
    await batch(
      (b) => b.insertAll(preferences, [
        for (final id in ayahs)
          PreferencesCompanion.insert(
            key: 'active_portion_${riwayah.id}_$id',
            value: id,
          ),
      ]),
    );
    for (final id in ayahs) {
      await markMemorized(riwayah, id, at);
    }
    await into(reviewSessions).insert(
      ReviewSessionsCompanion.insert(
        id: key,
        ayahIds: jsonEncode(ayahs),
        startedAt: at.toUtc(),
      ),
    );
  });

  Future<void> startReviews(
    Riwayah riwayah,
    Iterable<int> ids,
    DateTime at,
  ) async {
    final ayahs = ids.toSet().toList()..sort();
    if (ayahs.isEmpty) return;
    for (final id in ayahs) {
      riwayah.validateAyah(id);
    }
    final date = at.toLocal();
    await into(reviewSessions).insert(
      ReviewSessionsCompanion.insert(
        id: '${riwayah.id}:${date.year}-${date.month}-${date.day}',
        ayahIds: jsonEncode(ayahs),
        startedAt: at.toUtc(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<ReviewSettings> reviewSettings() async {
    final values = {
      for (final row in await select(preferences).get()) row.key: row.value,
    };
    final count = values['review_count'];
    if (count == null) return ReviewSettings();
    return ReviewSettings(
      intervals: [
        for (var i = 0; i < count; i++)
          Duration(minutes: values['review_gap_$i'] ?? 10),
      ],
      adaptive: values['review_adaptive'] == 1,
    );
  }

  Future<void> saveReviewSettings(ReviewSettings settings) =>
      transaction(() async {
        final values = {
          'review_count': settings.intervals.length,
          'review_adaptive': settings.adaptive ? 1 : 0,
          for (var i = 0; i < settings.intervals.length; i++)
            'review_gap_$i': settings.intervals[i].inMinutes,
        };
        for (final entry in values.entries) {
          await into(preferences).insertOnConflictUpdate(
            PreferencesCompanion.insert(key: entry.key, value: entry.value),
          );
        }
      });

  Future<List<ReviewSession>> sessions() => (select(
    reviewSessions,
  )..orderBy([(s) => OrderingTerm.asc(s.startedAt)])).get();

  Future<List<ReviewAttempt>> attempts(String sessionId) =>
      (select(reviewAttempts)
            ..where((a) => a.sessionId.equals(sessionId))
            ..orderBy([(a) => OrderingTerm.asc(a.ordinal)]))
          .get();

  Future<void> recordRecall(
    String sessionId,
    int ordinal,
    RecallRating rating,
    DateTime at,
  ) => transaction(() async {
    final session = await (select(
      reviewSessions,
    )..where((s) => s.id.equals(sessionId))).getSingle();
    final history = await attempts(sessionId);
    // A second tap or retry of an already saved attempt has no side effects.
    if (ordinal < history.length) return;
    final pending = ReviewScheduler().pending(
      startedAt: session.startedAt,
      attempts: [
        for (final a in history)
          RecallAttempt(a.completedAt, RecallRating.values[a.rating]),
      ],
      settings: await reviewSettings(),
      now: at,
    );
    if (pending.isEmpty ||
        ordinal != pending.first.ordinal ||
        !pending.first.isDue(at)) {
      throw StateError(
        'This review is not currently due. Refresh the schedule.',
      );
    }
    await into(reviewAttempts).insert(
      ReviewAttemptsCompanion.insert(
        sessionId: sessionId,
        ordinal: ordinal,
        rating: rating.index,
        completedAt: at.toUtc(),
      ),
    );
  });

  Future<void> markMemorized(Riwayah riwayah, int ayahId, DateTime at) {
    riwayah.validateAyah(ayahId);
    return into(memorizedAyahs).insertOnConflictUpdate(
      MemorizedAyahsCompanion.insert(
        riwayah: riwayah.id,
        numbering: riwayah.numbering,
        ayahId: ayahId,
        completedAt: at.toUtc(),
      ),
    );
  }

  Future<List<MemorizedAyah>> progress(Riwayah riwayah) =>
      (select(memorizedAyahs)
            ..where(
              (row) =>
                  row.riwayah.equals(riwayah.id) &
                  row.numbering.equals(riwayah.numbering),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.ayahId)]))
          .get();
}
