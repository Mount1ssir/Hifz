import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../core/data/app_databases.dart';
import '../core/data/user_database.dart';
import '../domain/review_scheduler.dart';
import 'quran_reader.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.databases});
  final AppDatabases databases;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen>
    with WidgetsBindingObserver {
  List<(ReviewSession, List<ReviewAttempt>)> _sessions = [];
  ReviewSettings _settings = ReviewSettings();
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final settings = await widget.databases.user.reviewSettings();
      final sessions = await widget.databases.user.sessions();
      final rows = <(ReviewSession, List<ReviewAttempt>)>[];
      for (final session in sessions) {
        rows.add((session, await widget.databases.user.attempts(session.id)));
      }
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _sessions = rows;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load your reviews.';
          _loading = false;
        });
      }
    }
  }

  String _time(DateTime time) {
    final local = time.toLocal();
    final labels = MaterialLocalizations.of(context);
    return '${labels.formatShortDate(local)} · ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  Future<void> _settingsDialog() async {
    final controller = TextEditingController(
      text: _settings.intervals.map((gap) => gap.inMinutes).join(', '),
    );
    var adaptive = _settings.adaptive;
    String? error;
    final result = await showDialog<ReviewSettings>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          return AlertDialog(
            title: const Text('Review rhythm'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Set the gaps between reviews in minutes. Each value adds one review, up to eight.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Intervals in minutes',
                      helperText: 'For example, 10, 60, 240',
                      errorText: error,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Adapt after recall'),
                    subtitle: const Text(
                      'Shorter gaps after difficult recall; longer after easy recall.',
                    ),
                    value: adaptive,
                    onChanged: (value) => update(() => adaptive = value),
                  ),
                  const Text(
                    'Changes affect pending reviews. Completed attempts stay saved.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => update(() {
                  controller.text = '10, 60, 240';
                  adaptive = true;
                  error = null;
                }),
                child: const Text('Reset defaults'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  try {
                    final gaps = controller.text
                        .split(',')
                        .map(
                          (value) => Duration(minutes: int.parse(value.trim())),
                        )
                        .toList();
                    Navigator.pop(
                      context,
                      ReviewSettings(intervals: gaps, adaptive: adaptive),
                    );
                  } catch (_) {
                    update(
                      () => error = 'Use 1–8 numbers, each from 1 to 1440.',
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    // Dialog routes may still be animating their text field after pop.
    if (result != null) {
      try {
        await widget.databases.user.saveReviewSettings(result);
        await _load();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save the review rhythm.')),
          );
        }
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consolidation'),
        actions: [
          IconButton(
            onPressed: _settingsDialog,
            tooltip: 'Review rhythm',
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Return. Recall. Strengthen.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_settings.intervals.length} reviews per portion · ${_settings.adaptive ? "Adaptive rhythm" : "Custom intervals"}',
                  ),
                  const SizedBox(height: 24),
                  if (_sessions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Complete your daily memorization portion to begin its spaced reviews.',
                        ),
                      ),
                    ),
                  for (final row in _sessions)
                    _sessionCard(row.$1, row.$2, now),
                ],
              ),
            ),
    );
  }

  Widget _sessionCard(
    ReviewSession session,
    List<ReviewAttempt> attempts,
    DateTime now,
  ) {
    final pending = ReviewScheduler().pending(
      startedAt: session.startedAt,
      attempts: [
        for (final a in attempts)
          RecallAttempt(a.completedAt, RecallRating.values[a.rating]),
      ],
      settings: _settings,
      now: now,
    );
    final ids = (jsonDecode(session.ayahIds) as List<dynamic>).cast<int>();
    final due = pending.isNotEmpty && pending.first.isDue(now);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ids.length} ayahs · ${MaterialLocalizations.of(context).formatShortDate(session.startedAt.toLocal())}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('${attempts.length} reviews completed'),
            for (final attempt in attempts)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '✓ ${RecallRating.values[attempt.rating].name} · ${_time(attempt.completedAt)}',
                ),
              ),
            if (pending.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('Reviews complete for this portion.'),
              )
            else ...[
              const Divider(height: 32),
              Text(
                due
                    ? 'Ready for recall'
                    : 'Next review · ${_time(pending.first.dueAt)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final review in pending.skip(1))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Then approximately ${_time(review.dueAt)}'),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: due
                    ? () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuranReader(
                              title: 'Recall ${pending.first.ordinal + 1}',
                              ayahs: [
                                for (final id in ids)
                                  widget.databases.quran
                                      .readRange(id, id)
                                      .single,
                              ],
                              initialMode: ReaderMode.cards,
                              startHidden: true,
                              onRecall: (rating) =>
                                  widget.databases.user.recordRecall(
                                    session.id,
                                    pending.first.ordinal,
                                    rating,
                                    DateTime.now(),
                                  ),
                            ),
                          ),
                        );
                        if (mounted) await _load();
                      }
                    : null,
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('Begin recall'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
