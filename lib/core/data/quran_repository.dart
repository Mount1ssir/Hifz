import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/riwayah.dart';

class QuranAyah {
  const QuranAyah({
    required this.id,
    required this.surah,
    required this.number,
    required this.text,
    required this.basmalahPrefix,
    required this.page,
    required this.juz,
  });

  final int id;
  final int surah;
  final int number;

  /// The original Tanzil text, including its opening Basmalah where supplied.
  final String text;
  final String basmalahPrefix;
  final int page;
  final int juz;
}

class QuranRepository {
  QuranRepository.open(File file, {required this.riwayah})
    : _db = sqlite3.open(file.path, mode: OpenMode.readOnly) {
    try {
      final metadata = {
        for (final row in _db.select('SELECT key, value FROM metadata'))
          row['key'] as String: row['value'] as String,
      };
      if (metadata['riwayah'] != riwayah.id ||
          metadata['numbering'] != riwayah.numbering ||
          metadata['total_ayahs'] != riwayah.totalAyahs.toString()) {
        throw StateError('The Quran dataset does not match the riwayah.');
      }
    } catch (_) {
      _db.close();
      rethrow;
    }
  }

  final Riwayah riwayah;
  final Database _db;

  List<QuranAyah> readRange(int first, int last) {
    riwayah.validateAyah(first);
    riwayah.validateAyah(last);
    if (last < first) {
      throw ArgumentError('The last ayah must follow the first.');
    }
    return _db
        .select('SELECT * FROM ayahs WHERE id BETWEEN ? AND ? ORDER BY id', [
          first,
          last,
        ])
        .map(
          (row) => QuranAyah(
            id: row['id'] as int,
            surah: row['surah'] as int,
            number: row['number'] as int,
            text: row['text'] as String,
            basmalahPrefix: row['basmalah_prefix'] as String,
            page: row['page'] as int,
            juz: row['juz'] as int,
          ),
        )
        .toList();
  }

  void close() => _db.close();
}
