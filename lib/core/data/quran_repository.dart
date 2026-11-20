import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/riwayah.dart';
import '../../domain/hifz_planner.dart';

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

class MushafWord {
  const MushafWord(this.ayahId, this.glyph);
  final int ayahId;
  final String glyph;
}

class MushafLine {
  const MushafLine(
    this.number,
    this.kind,
    this.centered,
    this.heading,
    this.words,
  );
  final int number;
  final String kind;
  final bool centered;
  final String? heading;
  final List<MushafWord> words;
}

class SurahInfo {
  const SurahInfo(this.number, this.name, this.page, this.ayahCount);
  final int number;
  final String name;
  final int page;
  final int ayahCount;
}

class QuranRepository {
  QuranRepository.open(File file, {required this.riwayah})
    : _path = file.path,
      _db = sqlite3.open(file.path, mode: OpenMode.readOnly) {
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
  final String _path;

  Future<List<QuranAyah>> searchVerses(String query) {
    final path = _path;
    final tradition = riwayah;
    return Isolate.run(() {
      final repository = QuranRepository.open(File(path), riwayah: tradition);
      try {
        final terms = _searchText(query.replaceAll('ٰ', ''))
            .split(' ')
            .where((t) => t.isNotEmpty)
            .toList();
        if (terms.isEmpty) return <QuranAyah>[];
        return repository.readRange(1, tradition.totalAyahs).where((ayah) {
          final words = _searchText(ayah.text).split(' ');
          for (var start = 0; start <= words.length - terms.length; start++) {
            var index = 0;
            while (index < terms.length) {
              final word = words[start + index];
              final term = terms[index];
              if (!word.replaceAll('ٰ', '').contains(term) &&
                  !word.replaceAll('ٰ', 'ا').contains(term)) {
                break;
              }
              index++;
            }
            if (index == terms.length) return true;
          }
          return false;
        }).toList();
      } finally {
        repository.close();
      }
    });
  }

  final Map<int, List<MushafLine>> _pageCache = {};
  List<SurahInfo>? _surahs;

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

  int get linesPerPage => int.parse(
    _db
            .select("SELECT value FROM metadata WHERE key = 'lines_per_page'")
            .single['value']
        as String,
  );

  late final Map<int, int> printedPageWeights = _readPageWeights();

  Map<int, int> _readPageWeights() {
    final weights = <int, int>{};
    final groups = _db.select(
      'SELECT page, ayah_id, COUNT(*) AS words, SUM(COUNT(*)) OVER (PARTITION BY page) AS total '
      'FROM mushaf_words GROUP BY page, ayah_id ORDER BY page, ayah_id',
    );
    var page = 0, words = 0, previous = 0;
    for (final row in groups) {
      if (page != row['page']) {
        page = row['page'] as int;
        words = 0;
        previous = 0;
      }
      words += row['words'] as int;
      final end = words * DailyQuota.pageScale ~/ (row['total'] as int);
      final id = row['ayah_id'] as int;
      weights[id] = (weights[id] ?? 0) + end - previous;
      previous = end;
    }
    return Map.unmodifiable(weights);
  }

  Map<int, int> lineWeights() {
    final weights = {
      for (final row in _db.select(
        'SELECT ayah_id, COUNT(*) AS weight FROM ayah_lines GROUP BY ayah_id',
      ))
        row['ayah_id'] as int: row['weight'] as int,
    };
    if (weights.length != riwayah.totalAyahs) {
      throw StateError('Incomplete printed-line metadata.');
    }
    return Map.unmodifiable(weights);
  }

  List<MushafLine> pageLines(int page) {
    RangeError.checkValueInInterval(page, 1, 604, 'page');
    final cached = _pageCache.remove(page);
    if (cached != null) {
      _pageCache[page] = cached;
      return cached;
    }
    final words = _db.select(
      'SELECT ayah_id, glyph, line FROM mushaf_words WHERE page=? ORDER BY id',
      [page],
    );
    final result = _db
        .select(
          'SELECT l.*, s.name FROM mushaf_lines l LEFT JOIN surahs s ON s.id=l.surah '
          'WHERE l.page=? ORDER BY l.line',
          [page],
        )
        .map(
          (row) => MushafLine(
            row['line'] as int,
            row['kind'] as String,
            row['centered'] == 1,
            row['name'] as String?,
            [
              for (final word in words)
                if (word['line'] == row['line'])
                  MushafWord(word['ayah_id'] as int, word['glyph'] as String),
            ],
          ),
        )
        .toList();
    if (_pageCache.length >= 12) _pageCache.remove(_pageCache.keys.first);
    _pageCache[page] = result;
    return result;
  }

  List<int> pagesForAyahs(Iterable<int> ids) {
    final pages = <int>{};
    for (final id in ids) {
      riwayah.validateAyah(id);
      pages.addAll(
        _db
            .select('SELECT DISTINCT page FROM ayah_lines WHERE ayah_id=?', [
              id,
            ])
            .map((row) => row['page'] as int),
      );
    }
    return pages.toList()..sort();
  }

  List<SurahInfo> surahs() => _surahs ??= _db
      .select(
        'SELECT s.*, MIN(w.page) AS page FROM surahs s '
        'JOIN mushaf_words w ON w.ayah_id=s.first_ayah_id GROUP BY s.id ORDER BY s.id',
      )
      .map(
        (row) => SurahInfo(
          row['id'] as int,
          row['name'] as String,
          row['page'] as int,
          row['ayah_count'] as int,
        ),
      )
      .toList();

  int pageForJuz(int juz) {
    RangeError.checkValueInInterval(juz, 1, 30, 'juz');
    return _db.select('SELECT MIN(page) AS page FROM ayahs WHERE juz=?', [
          juz,
        ]).single['page']
        as int;
  }

  String pageLabel(int page) {
    final row = _db.select(
      'SELECT s.name, a.juz FROM mushaf_words w JOIN ayahs a ON a.id=w.ayah_id '
      'JOIN surahs s ON s.id=a.surah WHERE w.page=? ORDER BY w.id LIMIT 1',
      [page],
    ).single;
    return '${row['name']} · الجزء ${row['juz']}';
  }

  void close() => _db.close();
}

final _marks = RegExp(r'[ؐ-ؚـً-ٟۖ-ۭ]');
final _alef = RegExp('[أإآٱ]');
final _spaces = RegExp(r'\s+');
String _searchText(String text) => text
    .replaceAll(_marks, '')
    .replaceAll(_alef, 'ا')
    .replaceAll('ى', 'ي')
    .trim()
    .replaceAll(_spaces, ' ');
