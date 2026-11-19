import 'package:material_ui/material_ui.dart';

import '../core/data/app_databases.dart';
import '../core/data/quran_repository.dart';
import '../domain/hifz_planner.dart';
import '../domain/range_set.dart';
import '../domain/riwayah.dart';
import 'quran_reader.dart';

class HifzScreen extends StatefulWidget {
  const HifzScreen({super.key, required this.databases});
  final AppDatabases databases;

  @override
  State<HifzScreen> createState() => _HifzScreenState();
}

class _HifzScreenState extends State<HifzScreen> with WidgetsBindingObserver {
  List<QuranAyah> _ayahs = [];
  int _quota = 5;
  QuotaUnit _unit = QuotaUnit.ayahs;
  int _memorized = 0;
  int _remainingSessions = 0;
  bool _loading = true;
  bool _saving = false;
  bool _completed = false;
  List<PlannedPortion> _plan = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_saving) _load();
  }

  Future<void> _load() async {
    try {
      final quota = await widget.databases.user.dailyQuota();
      final unit = await widget.databases.user.dailyQuotaUnit();
      final progress = await widget.databases.user.progress(Riwayah.hafs);
      final now = DateTime.now();
      final today = progress
          .where((entry) {
            final date = entry.completedAt.toLocal();
            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          })
          .map((entry) => entry.ayahId)
          .toList();
      if (today.isNotEmpty) {
        final startedAt = progress
            .where((entry) => today.contains(entry.ayahId))
            .map((entry) => entry.completedAt)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        await widget.databases.user.startReviews(
          Riwayah.hafs,
          today,
          startedAt,
        );
      }
      final baseline = RangeSet(
        progress.map((entry) => AyahRange(entry.ayahId, entry.ayahId)),
      );
      final plan = HifzPlanner().plan(
        riwayah: Riwayah.hafs,
        memorized: baseline,
        quota: switch (unit) {
          QuotaUnit.ayahs => DailyQuota.ayahs(quota),
          QuotaUnit.lines => DailyQuota.lines(
            quota,
            widget.databases.quran.lineWeights(),
          ),
          QuotaUnit.pages => DailyQuota.pages(
            quota,
            widget.databases.quran.lineWeights(),
            linesPerPage: widget.databases.quran.linesPerPage,
          ),
        },
      );
      final ids = today.isNotEmpty
          ? today
          : plan.isEmpty
          ? <int>[]
          : plan.first.ayahs.ids.toList();
      final ayahs = [
        for (final id in ids) widget.databases.quran.readRange(id, id).single,
      ];
      if (!mounted) return;
      setState(() {
        _quota = quota;
        _unit = unit;
        _memorized = baseline.length;
        _remainingSessions = plan.length;
        _plan = plan;
        _completed = today.isNotEmpty;
        _ayahs = ayahs;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load your progress. Please try again.';
        });
      }
    }
  }

  Future<void> _openReader() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuranReader(
          ayahs: _ayahs,
          title: 'Today’s portion',
          onComplete: _completed
              ? null
              : () => widget.databases.user.completePortion(
                  Riwayah.hafs,
                  _ayahs.map((ayah) => ayah.id),
                  DateTime.now(),
                ),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _syllabus() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Memorization syllabus')),
          body: _plan.isEmpty
              ? const Center(child: Text('All ayahs memorized.'))
              : ListView.builder(
                  itemCount: _plan.length,
                  itemBuilder: (context, index) {
                    final portion = _plan[index];
                    final first = widget.databases.quran
                        .readRange(
                          portion.ayahs.ranges.first.first,
                          portion.ayahs.ranges.first.first,
                        )
                        .single;
                    final last = widget.databases.quran
                        .readRange(
                          portion.ayahs.ranges.last.last,
                          portion.ayahs.ranges.last.last,
                        )
                        .single;
                    return ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(
                        'Surah ${first.surah}:${first.number} – ${last.surah}:${last.number}',
                      ),
                      subtitle: Text('${portion.ayahs.length} ayahs'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuranReader(
                            title: 'Portion ${index + 1}',
                            ayahs: [
                              for (final id in portion.ayahs.ids)
                                widget.databases.quran.readRange(id, id).single,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _editQuota() async {
    var selected = _quota;
    var selectedUnit = _unit;
    final result = await showDialog<(int, QuotaUnit)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          return AlertDialog(
            title: const Text('Daily memorization'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<QuotaUnit>(
                  value: selectedUnit,
                  isExpanded: true,
                  items: [
                    for (final unit in QuotaUnit.values)
                      DropdownMenuItem(value: unit, child: Text(unit.name)),
                  ],
                  onChanged: (unit) => update(() => selectedUnit = unit!),
                ),
                Text('$selected ${selectedUnit.name} per day'),
                Slider(
                  value: selected.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: '$selected',
                  onChanged: (value) => update(() => selected = value.round()),
                ),
                const Text('Changes apply to unfinished portions.'),
                if (selectedUnit != QuotaUnit.ayahs)
                  const Text(
                    'Printed-mushaf workload. Each ayah counts the lines it touches; '
                    'shared lines count for each ayah. A page equals 15 line units. '
                    'Portions keep ayahs whole and may exceed the quota.',
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, (selected, selectedUnit)),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.databases.user.setDailyQuota(result.$1, unit: result.$2);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your daily quota.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hifz'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(
            tooltip: 'Sources and licenses',
            icon: const Icon(Icons.info_outline),
            onPressed: () =>
                showLicensePage(context: context, applicationName: 'Hifz'),
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text(
                    'Your daily practice',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_memorized of ${Riwayah.hafs.totalAyahs} ayahs memorized',
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _memorized / Riwayah.hafs.totalAyahs,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    margin: EdgeInsets.zero,
                    color: colors.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _completed
                                ? 'Today’s portion completed'
                                : 'Today’s memorization',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_quota ${_unit.name} per day · $_remainingSessions portions remaining',
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _saving ? null : _editQuota,
                            icon: const Icon(Icons.tune),
                            label: const Text('Adjust daily quota'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_ayahs.isEmpty)
                    const Text(
                      'You have completed the Quran memorization plan.',
                    )
                  else ...[
                    Text(
                      '${_ayahs.length} ayahs · Surah ${_ayahs.first.surah}:${_ayahs.first.number}'
                      ' – ${_ayahs.last.surah}:${_ayahs.last.number}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _openReader,
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(
                        _completed
                            ? 'Read today’s portion'
                            : 'Begin memorization',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _syllabus,
                      icon: const Icon(Icons.list_alt),
                      label: const Text('View full syllabus'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _ayahs.first.text,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 30, height: 2),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
