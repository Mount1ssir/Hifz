import 'package:material_ui/material_ui.dart';

import '../core/data/app_databases.dart';
import 'baseline_screen.dart';
import 'reviews_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.databases});
  final AppDatabases databases;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _enabled;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await widget.databases.reminders.enabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الإعدادات')),
    body: ListView(
      children: [
        const ListTile(
          leading: Icon(Icons.language),
          title: Text('اللغة العربية'),
          subtitle: Text('لغة الواجهة الحالية'),
        ),
        SwitchListTile(
          title: const Text('تذكيرات تثبيت الحفظ'),
          subtitle: const Text(
            'قد يؤخر الهاتف التنبيهات قليلًا لتوفير الطاقة.',
          ),
          value: _enabled ?? false,
          onChanged: _enabled == null || _saving
              ? null
              : (value) async {
                  setState(() => _saving = true);
                  try {
                    final enabled = await widget.databases.reminders.setEnabled(
                      value,
                    );
                    if (mounted) setState(() => _enabled = enabled);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'تعذر تفعيل الإشعارات. تحقق من إذنها في إعدادات الهاتف.',
                          ),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
        ),
        ValueListenableBuilder<String?>(
          valueListenable: widget.databases.reminders.error,
          builder: (_, error, _) => error == null
              ? const SizedBox.shrink()
              : Padding(padding: const EdgeInsets.all(16), child: Text(error)),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('جلسات التثبيت وأوقاتها'),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => ReviewsScreen(databases: widget.databases),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.edit_note),
          title: const Text('تعديل المحفوظ السابق'),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => BaselineScreen(databases: widget.databases),
            ),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.menu_book),
          title: Text('المصحف'),
          subtitle: Text('رواية حفص · 604 صفحات · يعمل دون إنترنت'),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('المصادر والتراخيص'),
          onTap: () =>
              showLicensePage(context: context, applicationName: 'حفظ'),
        ),
      ],
    ),
  );
}
