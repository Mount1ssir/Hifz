import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'passage_picker.dart';
import '../core/data/app_databases.dart';
import '../domain/reading_goal.dart';
import '../domain/quarter_boundaries.dart';
import '../domain/riwayah.dart';
import 'quran_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key, required this.databases});
  final AppDatabases databases;
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late Future<List<ReadingGoal>> goals = widget.databases.user.readingGoals();
  late final Timer timer;
  int today = ReadingGoal.day(DateTime.now());
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      final day = ReadingGoal.day(DateTime.now());
      if (day != today) setState(() => today = day);
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  void reload() => setState(() => goals = widget.databases.user.readingGoals());
  Future<void> create() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _NewGoal(db: widget.databases)),
    );
    if (mounted && saved == true) reload();
  }

  Future<void> record(ReadingGoal goal) async {
    final quran = widget.databases.quran;
    final ids = goal.anchors.toSet();
    final verses = quran
        .readRange(1, 6236)
        .where((a) => ids.contains(a.id))
        .toList();
    final unread = goal.unread.toList();
    var first = unread.first, last = first;
    final names = quran.surahs();
    final labels = {
      for (final a in verses)
        a.id: goal.pages
            ? 'صفحة ${a.page}'
            : '${names[a.surah - 1].name} · ${a.number}',
    };
    final range = await showModalBottomSheet<(int, int)>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (_, update) {
          final count = unread.where((id) => id >= first && id <= last).length;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'تسجيل القراءة · ${goal.name}',
                    style: Theme.of(sheet).textTheme.titleMedium,
                  ),
                  for (final start in [true, false])
                    ListTile(
                      title: Text(
                        goal.pages
                            ? (start ? 'صفحة البداية' : 'صفحة النهاية')
                            : (start ? 'آية البداية' : 'آية النهاية'),
                      ),
                      trailing: ActionChip(
                        label: Text(labels[start ? first : last]!),
                        onPressed: () async {
                          final chosen = await pickVerse(
                            sheet,
                            quran,
                            start
                                ? verses
                                : verses.where((a) => a.id >= first).toList(),
                            start ? first : last,
                          );
                          if (chosen != null && sheet.mounted) {
                            update(() {
                              if (start) {
                                first = chosen;
                                if (last < first) last = first;
                              } else {
                                last = chosen;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  Text(
                    count == 0 ? 'مسجل سابقًا' : 'سيُضاف $count ${goal.unit}',
                  ),
                  FilledButton(
                    onPressed: count == 0
                        ? null
                        : () => Navigator.pop(sheet, (first, last)),
                    child: const Text('تأكيد الجلسة'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (range == null) return;
    try {
      await widget.databases.user.logGoalRange(goal, range.$1, range.$2);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر التسجيل. تحقق من مقدار التقدم ثم أعد المحاولة.',
            ),
          ),
        );
      }
    }
    if (mounted) reload();
  }

  Future<void> _delete(ReadingGoal goal) async {
    try {
      await widget.databases.user.deleteReadingGoal(goal.id);
      if (mounted) reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حذف الهدف. حاول مجددًا.')),
        );
      }
    }
  }

  Widget card(ReadingGoal g) {
    final next = g.remaining == 0
        ? null
        : widget.databases.quran
              .readRange(g.unread.first, g.unread.first)
              .single;
    return _SwipeGoal(
      key: ValueKey(g.id),
      onDelete: () => _delete(g),
      child: Card(
        child: ExpansionTile(
          key: PageStorageKey(g.id),
          title: Text(g.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${g.read} / ${g.anchors.length} ${g.unit} ${g.flexible ? '' : '· المطلوب اليوم ${g.due(today)}'}',
              ),
              LinearProgressIndicator(value: g.read / g.anchors.length),
            ],
          ),
          children: [
            ListTile(
              title: Text(
                g.flexible
                    ? 'تقدم القراءة'
                    : '${g.quota} ${g.unit} كل ${g.interval} يوم',
              ),
              subtitle: next == null
                  ? null
                  : Text(
                      'التالي: ${widget.databases.quran.surahs()[next.surah - 1].name}، الآية ${next.number} · صفحة ${next.page}',
                    ),
            ),
            if (next != null)
              Wrap(
                spacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuranScreen(
                          databases: widget.databases,
                          initialPage: next.page,
                        ),
                      ),
                    ),
                    child: const Text('بدء الجلسة'),
                  ),
                  FilledButton(
                    onPressed: () => record(g),
                    child: const Text('تسجيل ما قرأت'),
                  ),
                ],
              ),
            FutureBuilder(
              future: widget.databases.user.goalHistory(g.id),
              builder: (_, history) => Column(
                children: [
                  for (final item in history.data ?? <(DateTime, int)>[])
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.check),
                      title: Text('${item.$2} ${g.unit}'),
                      trailing: Text(
                        '${item.$1.day}/${item.$1.month}/${item.$1.year}',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('أهداف التثبيت'),
      actions: [
        TextButton.icon(
          onPressed: create,
          icon: const Icon(Icons.add),
          label: const Text('هدف جديد'),
        ),
      ],
    ),
    body: FutureBuilder(
      future: goals,
      builder: (_, state) {
        if (state.hasError) {
          return Center(
            child: TextButton(
              onPressed: reload,
              child: const Text('إعادة المحاولة'),
            ),
          );
        }
        if (!state.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.data!.isEmpty) {
          return Center(
            child: FilledButton.icon(
              onPressed: create,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('إنشاء أول هدف'),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final group in [
              (
                'أهداف مفتوحة',
                state.data!.where((g) => g.flexible && g.remaining > 0),
              ),
              ('أهداف اليوم', state.data!.where((g) => g.due(today) > 0)),
              (
                'القادمة',
                state.data!.where(
                  (g) => !g.flexible && g.remaining > 0 && g.due(today) == 0,
                ),
              ),
              ('المكتملة', state.data!.where((g) => g.remaining == 0)),
            ])
              if (group.$2.isNotEmpty) ...[
                ListTile(title: Text(group.$1)),
                ...group.$2.map(card),
              ],
          ],
        );
      },
    ),
  );
}

class _SwipeGoal extends StatefulWidget {
  const _SwipeGoal({super.key, required this.child, required this.onDelete});
  final Widget child;
  final Future<void> Function() onDelete;
  @override
  State<_SwipeGoal> createState() => _SwipeGoalState();
}

class _SwipeGoalState extends State<_SwipeGoal> {
  static const width = 72.0;
  double offset = 0;
  bool dragging = false;
  bool deleting = false;

  void settle(double velocity) => setState(() {
    dragging = false;
    offset = (velocity.abs() > 350 ? velocity > 0 : offset > width / 2)
        ? width
        : 0;
  });

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      children: [
        if (offset > 0)
          Positioned(
            left: 4,
            top: 4,
            bottom: 4,
            width: width,
            child: Material(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(12),
              child: IconButton(
                tooltip: 'حذف الهدف',
                icon: Icon(
                  Icons.remove_circle,
                  color: Theme.of(context).colorScheme.onError,
                ),
                onPressed: dragging || deleting
                    ? null
                    : () async {
                        setState(() => deleting = true);
                        try {
                          await widget.onDelete();
                        } finally {
                          if (mounted) setState(() => deleting = false);
                        }
                      },
              ),
            ),
          ),
        AnimatedContainer(
          duration: dragging
              ? Duration.zero
              : const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(offset, 0, 0),
          child: GestureDetector(
            onHorizontalDragStart: (_) => setState(() => dragging = true),
            onHorizontalDragUpdate: (details) => setState(
              () => offset = (offset + details.delta.dx).clamp(0.0, width),
            ),
            onHorizontalDragEnd: (details) =>
                settle(details.velocity.pixelsPerSecond.dx),
            onHorizontalDragCancel: () => settle(0),
            child: widget.child,
          ),
        ),
      ],
    ),
  );
}

class _NewGoal extends StatefulWidget {
  const _NewGoal({required this.db});
  final AppDatabases db;
  @override
  State<_NewGoal> createState() => _NewGoalState();
}

class _NewGoalState extends State<_NewGoal> {
  late final all = widget.db.quran.readRange(1, 6236);
  String name = '', scope = 'القرآن كاملًا', kind = 'السورة';
  int left = 1, right = 1;
  bool busy = false, editingRange = true;
  late final surahs = widget.db.quran.surahs();
  Set<int>? known;
  final ranges = <(int, int)>[];
  String? error;
  @override
  void initState() {
    super.initState();
    loadKnown();
  }

  Future<void> loadKnown() async {
    try {
      final ids = {
        ...await widget.db.user.memorizedBaseline(Riwayah.hafs),
        ...(await widget.db.user.progress(Riwayah.hafs)).map((a) => a.ayahId),
      };
      if (mounted) setState(() => known = ids);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تحميل المحفوظ');
    }
  }

  int group(int id) {
    final a = all[id - 1];
    return switch (kind) {
      'السورة' => a.surah,
      'الجزء' => a.juz,
      'الصفحة' => a.page,
      'الآية' => a.id,
      _ =>
        kind == 'الحزب'
            ? (quarterStarts.lastIndexWhere((v) => v <= id) ~/ 4) + 1
            : quarterStarts.lastIndexWhere((v) => v <= id) + 1,
    };
  }

  String endpointLabel(int id) => kind == 'السورة'
      ? surahs[group(id) - 1].name
      : kind == 'الآية'
      ? ref(id)
      : '$kind ${group(id)}';
  Future<void> chooseEndpoint(bool start) async {
    final items = start
        ? all
        : all.where((a) => group(a.id) >= group(left)).toList();
    int? result;
    if (kind == 'الآية') {
      result = await pickVerse(
        context,
        widget.db.quran,
        items,
        start ? left : right,
      );
    } else {
      final options = <int, int>{};
      for (final a in items) {
        options.putIfAbsent(group(a.id), () => a.id);
      }
      final values = options.values.toList();
      result = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => ListView.builder(
          itemCount: values.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(endpointLabel(values[i])),
            onTap: () => Navigator.pop(sheet, values[i]),
          ),
        ),
      );
    }
    if (result == null || !mounted) return;
    setState(() {
      editingRange = true;
      if (start) {
        left = result!;
        if (group(right) < group(left)) right = left;
      } else {
        right = result!;
      }
    });
  }

  (int, int) currentRange() => (
    all.firstWhere((a) => group(a.id) == group(left)).id,
    all.lastWhere((a) => group(a.id) == group(right)).id,
  );

  List<int> anchors() {
    final result = <int>[];
    final selected = [
      ...ranges,
      if (scope == 'نطاقات محددة' && editingRange) currentRange(),
    ];

    for (final a in all) {
      if (scope == 'محفوظي' && !(known?.contains(a.id) ?? false)) continue;
      if (scope == 'نطاقات محددة' &&
          !selected.any((r) => r.$1 <= a.id && a.id <= r.$2)) {
        continue;
      }
      result.add(a.id);
    }
    return result;
  }

  Widget choice(
    String label,
    String selected,
    List<String> options,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    initialValue: selected,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final v in options) DropdownMenuItem(value: v, child: Text(v)),
    ],
    onChanged: (v) {
      if (v != null) setState(() => change(v));
    },
  );
  String ref(int id) {
    final a = all[id - 1];
    return '${surahs[a.surah - 1].name} · ${a.number}';
  }

  @override
  Widget build(BuildContext context) {
    final units = anchors();
    final valid = units.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('هدف تثبيت جديد')),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'اسم الهدف'),
              onChanged: (v) => setState(() => name = v),
            ),
            choice('النطاق', scope, [
              'القرآن كاملًا',
              'محفوظي',
              'نطاقات محددة',
            ], (v) => scope = v),
            if (scope == 'نطاقات محددة') ...[
              choice(
                'تحديد حسب',
                kind,
                ['السورة', 'الجزء', 'الحزب', 'الربع', 'الصفحة', 'الآية'],
                (v) {
                  kind = v;
                  editingRange = true;
                  left = right = 1;
                },
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final start in [true, false])
                    ActionChip(
                      label: Text(
                        '${start ? 'من' : 'إلى'} ${endpointLabel(start ? left : right)}',
                      ),
                      onPressed: () => chooseEndpoint(start),
                    ),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('إضافة النطاق'),
                onPressed: () {
                  final range = currentRange();
                  setState(() {
                    if (!ranges.contains(range)) ranges.add(range);
                    editingRange = false;
                    error = null;
                  });
                },
              ),
              Wrap(
                children: [
                  for (final r in ranges)
                    InputChip(
                      label: Text('${ref(r.$1)} – ${ref(r.$2)}'),
                      onDeleted: () => setState(() => ranges.remove(r)),
                    ),
                ],
              ),
            ],
            if (scope == 'محفوظي' && known != null && units.isEmpty)
              const Text('لا يوجد محفوظ مسجل.'),
            if (error != null) Text(error!),
            FilledButton(
              onPressed: valid && name.trim().isNotEmpty && !busy
                  ? () async {
                      setState(() => busy = true);
                      try {
                        await widget.db.user.createReadingGoal(
                          name,
                          false,
                          units,
                          0,
                          1,
                        );
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (_) {
                        if (mounted) {
                          setState(() {
                            busy = false;
                            error = 'تعذر حفظ الهدف';
                          });
                        }
                      }
                    }
                  : null,
              child: const Text('حفظ الهدف'),
            ),
          ],
        ),
      ),
    );
  }
}
