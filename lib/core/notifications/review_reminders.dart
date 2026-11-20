import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/review_scheduler.dart';
import '../data/user_database.dart';

/// Absolute UTC instants preserve the schedule across device time-zone changes.
/// Android restores its persisted alarms after reboot using the plugin receiver.
class ReviewReminders {
  ReviewReminders(this.user, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;
  final DateTime Function() _now;
  final UserDatabase user;
  final _plugin = FlutterLocalNotificationsPlugin();
  final dueCount = ValueNotifier<int>(0);
  final openReviews = ValueNotifier<int>(0);
  final error = ValueNotifier<String?>(null);
  bool _ready = false;
  Timer? _timer;
  int _badgeRevision = 0;
  int _seenThrough = 0;
  static const _seenKey = 'hifz_history_seen_through';

  Future<void> _queue = Future<void>.value();

  Future<void> initialize() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_review'),
        ),
        onDidReceiveNotificationResponse: (_) => openReviews.value++,
      );
      _ready = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) openReviews.value++;
      await sync();
    } catch (_) {
      error.value = 'تعذر تشغيل التذكيرات. يمكنك إعادة المحاولة من الإعدادات.';
    }
  }

  Future<bool> enabled() async =>
      await user.preference('review_notifications') == 1;

  Future<bool> setEnabled(bool value) async {
    if (!_ready) await initialize();
    if (value) {
      final granted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
      if (!granted) {
        error.value =
            'لم يُسمح بالإشعارات. فعّلها من إعدادات الهاتف لتلقي التذكيرات.';
        await user.setPreference('review_notifications', 0);
        await sync();
        return false;
      }
    }
    error.value = null;
    await user.setPreference('review_notifications', value ? 1 : 0);
    await sync();
    return value;
  }

  Future<List<(String, ScheduledReview)>> _pending({bool badge = false}) async {
    final settings = await user.reviewSettings();
    final now = _now();
    final result = <(String, ScheduledReview)>[];
    for (final session in await user.sessions()) {
      final history = await user.attempts(session.id);
      for (final review in ReviewScheduler().pending(
        startedAt: session.startedAt,
        attempts: history
            .map(
              (a) =>
                  RecallAttempt(a.completedAt, RecallRating.values[a.rating]),
            )
            .toList(),
        settings: settings,
        // The history shortcut uses the configured times. Reopening the app
        // must not move its next dot forward when a recall is still overdue.
        now: badge ? session.startedAt : now,
      )) {
        result.add((session.id, review));
      }
    }
    return result;
  }

  Future<void> acknowledgeHistory() async {
    final opened = _now().microsecondsSinceEpoch;
    _seenThrough = opened;
    _badgeRevision++;
    dueCount.value = 0;
    try {
      await user.setPreference(_seenKey, opened);
    } finally {
      await refreshBadge();
    }
  }

  Future<void> refreshBadge() async {
    final revision = ++_badgeRevision;
    try {
      final stored = await user.preference(_seenKey);
      final pending = await _pending(badge: true);
      if (revision != _badgeRevision) return;
      if (stored > _seenThrough) _seenThrough = stored;
      final now = _now();
      var count = 0;
      DateTime? next;
      for (final (_, review) in pending) {
        final due = review.dueAt;
        if (due.microsecondsSinceEpoch <= _seenThrough) continue;
        if (due.isAfter(now)) {
          if (next == null || due.isBefore(next)) next = due;
        } else {
          count++;
        }
      }
      dueCount.value = count;
      _timer?.cancel();
      if (next != null) _timer = Timer(next.difference(now), refreshBadge);
    } catch (_) {
      // A failed read can be retried on the next schedule or lifecycle update.
    }
  }

  Future<void> sync() {
    // Serialize updates so an older reschedule cannot restore cancelled alarms.
    _queue = _queue.then((_) async {
      try {
        await refreshBadge();
        if (!_ready) return;
        await _plugin.cancelAll();
        if (!await enabled()) return;
        final pending = await _pending();
        final now = _now();
        for (final entry in pending) {
          final review = entry.$2;
          // Schedule only future Android alerts.
          if (!review.dueAt.isAfter(now)) continue;
          final bytes = sha256
              .convert(utf8.encode('${entry.$1}:${review.ordinal}'))
              .bytes;
          final id =
              ((bytes[0] << 24) |
                  (bytes[1] << 16) |
                  (bytes[2] << 8) |
                  bytes[3]) &
              0x7fffffff;
          await _plugin.zonedSchedule(
            id,
            'حان وقت تثبيت الحفظ',
            'الجلسة ${review.ordinal + 1}: استرجع وردك ثم قيّم تذكرك.',
            tz.TZDateTime.from(review.dueAt, tz.UTC),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'hifz_reviews',
                'مراجعة الحفظ',
                channelDescription: 'تذكيرات جلسات تثبيت الحفظ',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: entry.$1,
          );
        }
        error.value = null;
      } catch (_) {
        error.value =
            'حُفظ جدولك، لكن تعذرت جدولة التنبيهات. أعد المحاولة من الإعدادات.';
      }
    });
    return _queue;
  }

  void dispose() {
    _badgeRevision++;
    _timer?.cancel();
    dueCount.dispose();
    openReviews.dispose();
    error.dispose();
  }
}
