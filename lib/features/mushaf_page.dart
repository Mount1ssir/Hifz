import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/data/quran_repository.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({
    super.key,
    required this.quran,
    required this.page,
    this.selectedAyahs,
    this.highlightedAyah,
    this.contextAyahs = const {},
    this.hidden = false,
    this.revealedWordCount = 0,
  });
  final QuranRepository quran;
  final int page;
  final int? highlightedAyah;
  final Set<int>? selectedAyahs;
  final Set<int> contextAyahs;
  final bool hidden;
  final int revealedWordCount;

  static Future<void> preload(QuranRepository quran, int page) async {
    if (page < 1 || page > 604) return;
    await _MushafPageState.loadFont(page);
    quran.pageLines(page);
  }

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  static final Map<int, Future<void>> _fonts = {};
  static final Set<int> _loadedFonts = {};
  late Future<void> _ready = _load();
  late List<MushafLine> _lines = widget.quran.pageLines(widget.page);

  Future<void> _load() => loadFont(widget.page);
  static Future<void> loadFont(int page) {
    if (_loadedFonts.contains(page)) return Future<void>.value();
    return _fonts.putIfAbsent(page, () async {
      final loader = FontLoader('QpcPage$page');
      loader.addFont(rootBundle.load('assets/quran_fonts/p$page.ttf'));
      try {
        await loader.load();
        _loadedFonts.add(page);
      } catch (_) {
        _fonts.remove(page);
        rethrow;
      }
    });
  }

  final Map<String, double> _widths = {};
  double? _maxWidth;
  Set<MushafWord> _revealedWords = {};

  @override
  void didUpdateWidget(MushafPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      _widths.clear();
      _maxWidth = null;
      _lines = widget.quran.pageLines(widget.page);
      _ready = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: () => setState(() => _ready = _load()),
            child: const Text('إعادة تحميل خط الصفحة'),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(100.0, constraints.maxWidth - 24);
          final font = 'QpcPage${widget.page}';
          _maxWidth ??= _lines
              .where((line) => line.kind == 'ayah')
              .fold<double>(
                1,
                (maximum, line) => math.max(
                  maximum,
                  _wordWidth(
                    line.words.map((w) => w.glyph).join(' '),
                    font,
                    32,
                  ),
                ),
              );
          final maxWidth = _maxWidth!;
          _revealedWords = _lines
              .expand((line) => line.words)
              .where(
                (word) => widget.selectedAyahs?.contains(word.ayahId) ?? true,
              )
              .take(widget.revealedWordCount)
              .toSet();
          final lines = widget.selectedAyahs == null
              ? _lines
              : _lines
                    .where(
                      (line) =>
                          line.kind == 'ayah' &&
                          line.words.any(
                            (word) =>
                                (widget.selectedAyahs!.contains(word.ayahId) ||
                                widget.contextAyahs.contains(word.ayahId)),
                          ),
                    )
                    .toList();
          final widthSize = 32 * width / maxWidth;
          // Use the physical window, never the changing space left by controls.
          // Reserve compact chrome once in both focus and practice modes.
          final window = MediaQuery.sizeOf(context);
          final insets = MediaQuery.viewPaddingOf(context);
          final stableHeight = math.max(
            180.0,
            window.height - insets.vertical - 208,
          );
          final heightSize = stableHeight / math.max(8, lines.length) / 1.85;
          final fontSize = math.min(widthSize, math.max(12.0, heightSize));
          final rowHeight = fontSize * 1.85;
          final pageHeight = math.max(
            rowHeight * lines.length + 48,
            constraints.maxHeight,
          );
          return SingleChildScrollView(
            child: SizedBox(
              height: pageHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final line in lines)
                      SizedBox(
                        height: rowHeight,
                        child: _line(line, font, fontSize),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  Widget _line(MushafLine line, String font, double size) {
    if (line.kind == 'surah_name') {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffc1cbbd)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'سُورَة ${line.heading ?? ''}',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: size * .7),
          ),
        ),
      );
    }
    if (line.kind == 'basmallah') {
      return Center(
        child: Text(
          'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: size * .7),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final words = line.words;
        final widths = [
          for (final word in words) _wordWidth(word.glyph, font, size),
        ];
        final space = line.centered
            ? _wordWidth(' ', font, size)
            : math.max(
                0.0,
                (constraints.maxWidth - widths.fold(0.0, (a, b) => a + b)) /
                    math.max(1, words.length - 1),
              );
        bool masked(int i) =>
            widget.hidden &&
            (widget.selectedAyahs?.contains(words[i].ayahId) ?? true) &&
            !_revealedWords.contains(words[i]);
        final pieces = <Widget>[];
        for (var i = 0; i < words.length; i++) {
          if (i > 0) pieces.add(SizedBox(width: space));
          final word = words[i];
          var width = widths[i];
          if (masked(i)) {
            while (i + 1 < words.length && masked(i + 1)) {
              width += space + widths[++i];
            }
            pieces.add(
              Container(
                width: width,
                height: size * .6,
                decoration: BoxDecoration(
                  color: const Color(0xffd5dfd8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          } else {
            final visible =
                widget.selectedAyahs == null ||
                widget.selectedAyahs!.contains(word.ayahId) ||
                widget.contextAyahs.contains(word.ayahId);
            pieces.add(
              SizedBox(
                width: width,
                child: visible
                    ? Text(
                        word.glyph,
                        textDirection: TextDirection.rtl,
                        textScaler: TextScaler.noScaling,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          backgroundColor: widget.highlightedAyah == word.ayahId
                              ? const Color(0xffd4e9d9)
                              : null,
                          fontFamily: font,
                          fontSize: size,
                          height: 1.4,
                          color:
                              widget.selectedAyahs != null &&
                                  !widget.selectedAyahs!.contains(word.ayahId)
                              ? const Color(0xff828984)
                              : const Color(0xff111b15),
                        ),
                      )
                    : null,
              ),
            );
          }
        }
        return Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: line.centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: pieces,
        );
      },
    );
  }

  double _wordWidth(String glyph, String font, double size) {
    final cached = _widths[glyph];
    if (cached != null) return cached * size / 32;
    final painter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(fontFamily: font, fontSize: 32),
      ),
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
    )..layout();
    final width = painter.width;
    painter.dispose();
    _widths[glyph] = width;
    return width * size / 32;
  }
}
