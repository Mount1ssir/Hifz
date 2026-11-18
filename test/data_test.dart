import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/core/data/quran_repository.dart';
import 'package:hifz/core/data/user_database.dart';
import 'package:hifz/domain/riwayah.dart';
import 'package:hifz/domain/hifz_planner.dart';
import 'package:hifz/domain/review_scheduler.dart';

void main() {
  test('review sessions and recall retries survive reopening', () async {
    final directory = await Directory.systemTemp.createTemp('hifz-reviews');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/user.db');
    var db = UserDatabase(NativeDatabase(file));
    final start = DateTime.utc(2026, 11, 18, 10);
    await db.completePortion(Riwayah.hafs, [1, 2], start);
    await db.completePortion(Riwayah.hafs, [1, 2], start);
    final session = (await db.sessions()).single;
    await expectLater(
      db.recordRecall(session.id, 0, RecallRating.good, start),
      throwsStateError,
    );
    final at = start.add(const Duration(minutes: 10));
    await db.recordRecall(session.id, 0, RecallRating.hard, at);
    await db.recordRecall(session.id, 0, RecallRating.hard, at);
    await db.saveReviewSettings(
      ReviewSettings(
        intervals: [const Duration(minutes: 3), const Duration(minutes: 15)],
        adaptive: false,
      ),
    );
    await db.close();
    db = UserDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect((await db.sessions()).length, 1);
    expect((await db.attempts(session.id)).length, 1);
    expect((await db.progress(Riwayah.hafs)).length, 2);
    expect((await db.reviewSettings()).intervals.last.inMinutes, 15);
    expect((await db.reviewSettings()).adaptive, isFalse);
  });

  test('version 1 progress survives the settings migration', () async {
    final directory = await Directory.systemTemp.createTemp('hifz-migration');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/user.db');
    final old = sqlite3.open(file.path);
    old.execute(
      'CREATE TABLE memorized_ayahs (riwayah TEXT NOT NULL, '
      'numbering TEXT NOT NULL, ayah_id INTEGER NOT NULL, '
      'completed_at INTEGER NOT NULL, PRIMARY KEY (riwayah, numbering, ayah_id))',
    );
    old.execute(
      "INSERT INTO memorized_ayahs VALUES ('hafs', 'hafs-kufi', 8, 0)",
    );
    old.execute('PRAGMA user_version = 1');
    old.close();
    final db = UserDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect((await db.progress(Riwayah.hafs)).single.ayahId, 8);
    expect(await db.dailyQuota(), 5);
    expect(await db.dailyQuotaUnit(), QuotaUnit.ayahs);
    await db.setDailyQuota(12, unit: QuotaUnit.lines);
    expect(await db.dailyQuota(), 12);
    expect(await db.dailyQuotaUnit(), QuotaUnit.lines);
  });

  test('bundled Quran exposes ordered ranges and validates bounds', () {
    final quran = QuranRepository.open(
      File('assets/data/quran.db'),
      riwayah: Riwayah.hafs,
    );
    addTearDown(quran.close);
    expect(quran.linesPerPage, 15);
    expect(quran.lineWeights().length, Riwayah.hafs.totalAyahs);
    expect(quran.lineWeights().values.every((weight) => weight > 0), isTrue);
    expect(quran.readRange(1, Riwayah.hafs.totalAyahs).length, 6236);
    expect(quran.readRange(8, 8).single.basmalahPrefix, isNotEmpty);
    expect(() => quran.readRange(0, 1), throwsRangeError);
    expect(() => quran.readRange(3, 2), throwsArgumentError);
  });

  test(
    'progress survives reopen and repeated completion is idempotent',
    () async {
      final directory = await Directory.systemTemp.createTemp('hifz-progress');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/user.db');
      var db = UserDatabase(NativeDatabase(file));
      final at = DateTime.utc(2026, 11, 17);
      await db.markMemorized(Riwayah.hafs, 8, at);
      await db.markMemorized(Riwayah.hafs, 8, at);
      await db.close();
      db = UserDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final rows = await db.progress(Riwayah.hafs);
      expect(rows.single.ayahId, 8);
      expect(rows.single.completedAt.toUtc(), at);
      expect(() => db.markMemorized(Riwayah.hafs, 0, at), throwsRangeError);
    },
  );
}
