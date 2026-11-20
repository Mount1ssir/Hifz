import 'package:material_ui/material_ui.dart';

import 'core/data/app_databases.dart';
import 'domain/riwayah.dart';
import 'features/hifz_screen.dart';
import 'features/quran_screen.dart';
import 'features/goals_screen.dart';
import 'features/reviews_screen.dart';
import 'features/reader_controls.dart';

class HifzApp extends StatefulWidget {
  const HifzApp({super.key, this.openDatabases});
  final Future<AppDatabases> Function()? openDatabases;

  @override
  State<HifzApp> createState() => _HifzAppState();
}

class _HifzAppState extends State<HifzApp> {
  late Future<AppDatabases> _opening = _open();

  Future<AppDatabases> _open() async {
    final databases =
        await (widget.openDatabases?.call() ??
            AppDatabases.open(riwayah: Riwayah.hafs));
    debugPrint('Hifz database open: ${databases.openTime.inMilliseconds} ms');
    return databases;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حفظ',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff226653),
          primary: const Color(0xff226653),
          primaryContainer: const Color(0xffe6eee6),
          surface: const Color(0xfffaf9f5),
        ),
        scaffoldBackgroundColor: const Color(0xfff8f6ef),
        useMaterial3: true,
      ),
      home: FutureBuilder<AppDatabases>(
        future: _opening,
        builder: (context, snapshot) {
          if (snapshot.hasData) return _Home(databases: snapshot.data!);
          return Scaffold(
            appBar: AppBar(title: const Text('حفظ')),
            body: Center(
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('تعذر فتح بيانات القرآن.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => setState(() => _opening = _open()),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('جارٍ فتح القرآن…'),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.databases});
  final AppDatabases databases;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with WidgetsBindingObserver {
  int _index = 0;
  bool _focus = false;
  void _setFocus(bool value) => setState(() => _focus = value);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.databases.reminders.openReviews.value > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openReviews());
    }
    widget.databases.reminders.openReviews.addListener(_openReviews);
  }

  void _openReviews() {
    if (mounted) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewsScreen(databases: widget.databases),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.databases.reminders.sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.databases.reminders.openReviews.removeListener(_openReviews);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: switch (_index) {
      0 => QuranScreen(databases: widget.databases, onFocusChanged: _setFocus),
      1 => HifzScreen(databases: widget.databases, onFocusChanged: _setFocus),
      _ => GoalsScreen(databases: widget.databases),
    },
    bottomNavigationBar: ReaderControls(
      visible: !_focus,
      child: NavigationBar(
        height: 60,
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'القرآن',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'الحفظ',
          ),
          NavigationDestination(
            icon: const Icon(Icons.flag_outlined),
            selectedIcon: const Icon(Icons.flag_outlined),
            label: 'التثبيت',
          ),
        ],
      ),
    ),
  );
}
