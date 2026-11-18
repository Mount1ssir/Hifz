import 'package:material_ui/material_ui.dart';

import 'core/data/app_databases.dart';
import 'domain/riwayah.dart';
import 'features/hifz_screen.dart';
import 'features/reviews_screen.dart';

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
      title: 'Hifz',
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
            appBar: AppBar(title: const Text('Hifz')),
            body: Center(
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Unable to open your Quran data.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => setState(() => _opening = _open()),
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Opening your Quran…'),
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

class _HomeState extends State<_Home> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _index == 0
        ? HifzScreen(databases: widget.databases)
        : ReviewsScreen(databases: widget.databases),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (index) => setState(() => _index = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.auto_stories_outlined),
          selectedIcon: Icon(Icons.auto_stories),
          label: 'Memorize',
        ),
        NavigationDestination(
          icon: Icon(Icons.history),
          selectedIcon: Icon(Icons.history),
          label: 'Review',
        ),
      ],
    ),
  );
}
