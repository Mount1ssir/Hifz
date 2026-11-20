import 'package:material_ui/material_ui.dart';

import '../core/data/app_databases.dart';
import 'mushaf_page.dart';
import 'verse_search.dart';
import '../core/data/quran_repository.dart';
import 'reader_controls.dart';
import 'settings_screen.dart';
import '../core/arabic.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({
    super.key,
    required this.databases,
    this.onFocusChanged,
    this.initialPage,
  });
  final int? initialPage;
  final AppDatabases databases;
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  PageController? _controller;
  int _page = 1;
  QuranAyah? _match;

  Future<void> _search() async {
    final ayah = await Navigator.push<QuranAyah>(
      context,
      MaterialPageRoute(
        builder: (_) => VerseSearch(quran: widget.databases.quran),
      ),
    );
    if (ayah == null || !mounted) return;
    setState(() => _match = ayah);
    _controller?.jumpToPage(ayah.page - 1);
  }

  Set<int> _bookmarks = {};
  String? _error;
  bool _bookmarkSaving = false;
  bool _focus = false;
  void _toggleFocus() {
    setState(() => _focus = !_focus);
    widget.onFocusChanged?.call(_focus);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page =
          widget.initialPage ?? await widget.databases.user.readingPage();
      final bookmarks = await widget.databases.user.bookmarks();
      if (!mounted) return;
      setState(() {
        _page = page;
        _bookmarks = bookmarks;
        _controller = PageController(initialPage: page - 1);
        _error = null;
      });
      _preload(page);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر استعادة موضع القراءة.');
      }
    }
  }

  void _preload(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final next in [page - 1, page + 1]) {
        MushafPage.preload(
          widget.databases.quran,
          next,
        ).catchError((Object _) {});
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _bookmark() async {
    final page = _page;
    final enabled = !_bookmarks.contains(page);
    setState(() => _bookmarkSaving = true);
    try {
      await widget.databases.user.setBookmark(page, enabled);
      if (mounted) {
        setState(() {
          if (enabled) {
            _bookmarks.add(page);
          } else {
            _bookmarks.remove(page);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر حفظ العلامة.')));
      }
    } finally {
      if (mounted) setState(() => _bookmarkSaving = false);
    }
  }

  Future<void> _navigate() async {
    final page = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      builder: (_) => FractionallySizedBox(
        heightFactor: .9,
        child: _QuranIndex(databases: widget.databases, bookmarks: _bookmarks),
      ),
    );
    if (page != null && mounted) _controller?.jumpToPage(page - 1);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_focus,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _focus) _toggleFocus();
    },
    child: Scaffold(
      backgroundColor: const Color(0xfffaf9f6),
      body: SafeArea(
        child: Column(
          children: [
            ReaderControls(
              visible: !_focus,
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'الإعدادات',
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SettingsScreen(databases: widget.databases),
                        ),
                      ),
                      icon: const Icon(Icons.menu),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _controller == null ? null : _navigate,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.databases.quran
                                    .pageLabel(_page)
                                    .split(' · ')
                                    .first,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'صفحة $_page · ${widget.databases.quran.pageLabel(_page).split(' · ').last}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'بحث في الآيات',
                      onPressed: _controller == null ? null : _search,
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(
                      tooltip: _bookmarks.contains(_page)
                          ? 'إزالة العلامة'
                          : 'حفظ علامة',
                      onPressed: _bookmarkSaving || _controller == null
                          ? null
                          : _bookmark,
                      icon: Icon(
                        _bookmarks.contains(_page)
                            ? Icons.bookmark
                            : Icons.bookmark_outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _controller == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: _load,
                              child: Text('$_error إعادة المحاولة'),
                            ),
                    )
                  : PageView.builder(
                      controller: _controller,
                      reverse: false,
                      itemCount: 604,
                      onPageChanged: (index) async {
                        setState(() {
                          _page = index + 1;
                          if (_match?.page != _page) _match = null;
                        });
                        _preload(index + 1);
                        try {
                          await widget.databases.user.saveReadingPage(
                            index + 1,
                          );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تعذر حفظ موضع القراءة.'),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (_, index) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggleFocus,
                        child: MushafPage(
                          quran: widget.databases.quran,
                          page: index + 1,
                          highlightedAyah: _match?.id,
                        ),
                      ),
                    ),
            ),
            ReaderControls(
              visible: !_focus,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Align(
                  alignment: _page.isOdd
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    '$_page',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuranIndex extends StatelessWidget {
  const _QuranIndex({required this.databases, required this.bookmarks});
  final AppDatabases databases;
  final Set<int> bookmarks;

  @override
  Widget build(BuildContext context) {
    final surahs = databases.quran.surahs();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تصفح القرآن'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'السور'),
              Tab(text: 'الجزء'),
              Tab(text: 'العلامات'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextFormField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'رقم الصفحة · 1–604',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.arrow_forward),
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final page = int.tryParse(normalizeDigits(value));
                  return page == null || page < 1 || page > 604
                      ? 'أدخل صفحة بين 1 و604'
                      : null;
                },
                onFieldSubmitted: (value) {
                  final page = int.tryParse(normalizeDigits(value));
                  if (page != null && page >= 1 && page <= 604) {
                    Navigator.pop(context, page);
                  }
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView.builder(
                    itemCount: surahs.length,
                    itemBuilder: (context, index) {
                      final surah = surahs[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${surah.number}')),
                        title: Text(
                          surah.name,
                          textDirection: TextDirection.rtl,
                        ),
                        subtitle: Text(
                          '${surah.ayahCount} آية · الصفحة ${surah.page}',
                        ),
                        onTap: () => Navigator.pop(context, surah.page),
                      );
                    },
                  ),
                  ListView.builder(
                    itemCount: 30,
                    itemBuilder: (context, index) => ListTile(
                      title: Text('الجزء ${index + 1}'),
                      trailing: Text(
                        'الصفحة ${databases.quran.pageForJuz(index + 1)}',
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        databases.quran.pageForJuz(index + 1),
                      ),
                    ),
                  ),
                  bookmarks.isEmpty
                      ? const Center(
                          child: Text('احفظ علامة على صفحة لتجدها هنا.'),
                        )
                      : ListView(
                          children: [
                            for (final page in bookmarks.toList()..sort())
                              ListTile(
                                leading: const Icon(Icons.bookmark),
                                title: Text('الصفحة $page'),
                                subtitle: Text(databases.quran.pageLabel(page)),
                                onTap: () => Navigator.pop(context, page),
                              ),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
