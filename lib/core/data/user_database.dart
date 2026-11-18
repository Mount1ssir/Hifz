import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/review_scheduler.dart';

import '../../domain/riwayah.dart';
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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(preferences);
      if (from < 3) {
        await m.createTable(reviewSessions);
        await m.createTable(reviewAttempts);
      }
    },
  );

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
    final key = '${riwayah.id}:${local.year}-${local.month}-${local.day}';
    final existing = await (select(
      reviewSessions,
    )..where((s) => s.id.equals(key))).getSingleOrNull();
    if (existing != null) return;
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
