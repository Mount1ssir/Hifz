import 'package:material_ui/material_ui.dart';

import '../core/data/quran_repository.dart';
import '../domain/review_scheduler.dart';

enum ReaderMode { page, cards }

class QuranReader extends StatefulWidget {
  const QuranReader({
    super.key,
    required this.ayahs,
    required this.title,
    this.initialMode = ReaderMode.page,
    this.startHidden = false,
    this.onComplete,
    this.onRecall,
  });

  final List<QuranAyah> ayahs;
  final String title;
  final ReaderMode initialMode;
  final bool startHidden;
  final Future<void> Function()? onComplete;
  final Future<void> Function(RecallRating)? onRecall;

  @override
  State<QuranReader> createState() => _QuranReaderState();
}

class _QuranReaderState extends State<QuranReader> {
  late ReaderMode _mode = widget.initialMode;
  late final List<List<QuranAyah>> _pages = _groupPages();
  late final Set<int> _visible = widget.startHidden
      ? <int>{}
      : widget.ayahs.map((ayah) => ayah.id).toSet();
  final ScrollController _scroll = ScrollController();
  int _index = 0;
  double _fontSize = 30;
  bool _saving = false;
  String? _error;

  List<List<QuranAyah>> _groupPages() {
    final pages = <List<QuranAyah>>[];
    for (final ayah in widget.ayahs) {
      if (pages.isEmpty || pages.last.last.page != ayah.page) pages.add([]);
      pages.last.add(ayah);
    }
    return pages;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int get _pageIndex => _pages.indexWhere(
    (page) => page.any((a) => a.id == widget.ayahs[_index].id),
  );
  List<QuranAyah> get _current =>
      _mode == ReaderMode.cards ? [widget.ayahs[_index]] : _pages[_pageIndex];
  bool get _shown => _current.every((ayah) => _visible.contains(ayah.id));
  bool get _last => _mode == ReaderMode.cards
      ? _index == widget.ayahs.length - 1
      : _pageIndex == _pages.length - 1;
  bool get _first => _mode == ReaderMode.cards ? _index == 0 : _pageIndex == 0;

  void _move(int direction) {
    setState(() {
      _index = _mode == ReaderMode.cards
          ? _index + direction
          : widget.ayahs.indexOf(_pages[_pageIndex + direction].first);
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _toggleText() => setState(() {
    final hide = _shown;
    for (final ayah in _current) {
      if (hide) {
        _visible.remove(ayah.id);
      } else {
        _visible.add(ayah.id);
      }
    }
  });

  Future<void> _save({RecallRating? rating}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (rating != null) {
        await widget.onRecall!(rating);
      } else {
        await widget.onComplete!();
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save. Try again, or return to refresh the schedule.';
        });
      }
    }
  }

  Future<void> _textSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Arabic text size'),
                Slider(
                  value: _fontSize,
                  min: 22,
                  max: 44,
                  divisions: 11,
                  label: '${_fontSize.round()}',
                  onChanged: (value) {
                    update(() => _fontSize = value);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ayahs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('No ayahs in this portion.')),
      );
    }
    final current = _current;
    final ayah = current.first;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: const Color(0xfffaf9f6),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Surah ${ayah.surah} · Page ${ayah.page} · Juz ${ayah.juz}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _saving ? null : _textSettings,
              tooltip: 'Text size',
              icon: const Icon(Icons.text_fields),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.ayahs.first.surah}:${widget.ayahs.first.number} – '
                      '${widget.ayahs.last.surah}:${widget.ayahs.last.number}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  SegmentedButton<ReaderMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ReaderMode.page,
                        icon: Icon(Icons.menu_book),
                        label: Text('Read'),
                      ),
                      ButtonSegment(
                        value: ReaderMode.cards,
                        icon: Icon(Icons.style_outlined),
                        label: Text('Cards'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: _saving
                        ? null
                        : (value) {
                            setState(() => _mode = value.single);
                            if (_scroll.hasClients) _scroll.jumpTo(0);
                          },
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(
                  20,
                  _mode == ReaderMode.cards ? 28 : 12,
                  20,
                  24,
                ),
                child: _mode == ReaderMode.cards ? _card(ayah) : _page(current),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: TextStyle(color: colors.error)),
              ),
            SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: _mode == ReaderMode.cards
                          ? (_index + 1) / widget.ayahs.length
                          : (_pageIndex + 1) / _pages.length,
                      minHeight: 3,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _first || _saving ? null : () => _move(-1),
                          tooltip: 'Previous',
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          onPressed: _saving ? null : _toggleText,
                          tooltip: _shown ? 'Hide text' : 'Reveal text',
                          icon: Icon(
                            _shown
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                        Text(
                          _mode == ReaderMode.cards
                              ? 'Ayah ${_index + 1} / ${widget.ayahs.length}'
                              : 'Page ${_pageIndex + 1} / ${_pages.length}',
                        ),
                        FilledButton.tonal(
                          onPressed: _last || _saving ? null : () => _move(1),
                          child: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    if (_last &&
                        widget.onRecall != null &&
                        _visible.length == widget.ayahs.length) ...[
                      const Text('How was your recall of the whole portion?'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final rating in RecallRating.values)
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => _save(rating: rating),
                              child: Text(switch (rating) {
                                RecallRating.again => 'Again',
                                RecallRating.hard => 'Hard',
                                RecallRating.good => 'Good',
                                RecallRating.easy => 'Easy',
                              }),
                            ),
                        ],
                      ),
                    ] else if (_last && widget.onRecall != null)
                      const Text(
                        'Reveal each ayah to compare before rating the portion.',
                      ),
                    if (_last && widget.onComplete != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _save(),
                          icon: const Icon(Icons.check),
                          label: Text(
                            _saving ? 'Saving…' : 'Mark portion memorized',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(List<QuranAyah> ayahs) {
    final spans = <InlineSpan>[];
    for (var index = 0; index < ayahs.length; index++) {
      final ayah = ayahs[index];
      if (index > 0 && ayah.id != ayahs[index - 1].id + 1) {
        spans.add(const TextSpan(text: '\n⋯\n'));
      }
      if (_visible.contains(ayah.id)) {
        spans.add(TextSpan(text: '${ayah.text} ﴿${ayah.number}﴾ '));
      } else {
        spans.add(
          WidgetSpan(
            child: Semantics(
              label: 'Hidden ayah ${ayah.surah}:${ayah.number}',
              child: Container(
                height: 36,
                width: 160,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xffdce3ee),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        );
      }
    }
    return Column(
      children: [
        if (!_shown)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Recite from memory, then reveal to compare.'),
          ),
        Text.rich(
          TextSpan(children: spans),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
          style: TextStyle(
            fontSize: _fontSize,
            height: 2.15,
            color: const Color(0xff202624),
          ),
        ),
      ],
    );
  }

  Widget _card(QuranAyah ayah) => Stack(
    children: [
      Positioned(
        top: 0,
        left: 24,
        right: 24,
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xffd7dfeb),
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 360),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xffeef0fc), Color(0xffe2e8f6), Color(0xffa9c5e9)],
            ),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_shown)
                Text(
                  ayah.text,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: _fontSize + 2,
                    height: 2.1,
                    color: const Color(0xff172b3f),
                  ),
                )
              else ...[
                const Text(
                  'Recite this ayah from memory',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < 3; i++)
                  Container(
                    height: 34,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xffcfd9ef),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                OutlinedButton(
                  onPressed: _toggleText,
                  child: const Text('Reveal ayah'),
                ),
              ],
              const SizedBox(height: 28),
              Text(
                'Surah ${ayah.surah} · Ayah ${ayah.number}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
