import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/core/data/quran_repository.dart';
import 'package:hifz/core/data/user_database.dart';
import 'package:hifz/domain/riwayah.dart';

void main() {
  test('bundled Quran exposes ordered ranges and validates bounds', () {
    final quran = QuranRepository.open(
      File('assets/data/quran.db'),
      riwayah: Riwayah.hafs,
    );
    addTearDown(quran.close);
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
