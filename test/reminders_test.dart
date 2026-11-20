import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:hifz/core/data/user_database.dart';
import 'package:hifz/core/notifications/review_reminders.dart';
import 'package:hifz/domain/review_scheduler.dart';
import 'package:hifz/domain/riwayah.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('opening history clears due dots until the next scheduled time across restarts', () async {
    final user = UserDatabase(NativeDatabase.memory());
    addTearDown(user.close);
    final start = DateTime.utc(2026, 11, 20, 8);
    var now = start.add(const Duration(minutes: 2));
    await user.saveReviewSettings(
      ReviewSettings(
        intervals: [const Duration(minutes: 1), const Duration(minutes: 3)],
      ),
    );
    await user.completePortion(Riwayah.hafs, [1], start);
    var reminders = ReviewReminders(user, clock: () => now);
    await reminders.refreshBadge();
    expect(reminders.dueCount.value, 1);
    await reminders.acknowledgeHistory();
    expect(reminders.dueCount.value, 0);
    reminders.dispose();
    reminders = ReviewReminders(user, clock: () => now);
    addTearDown(reminders.dispose);
    now = start.add(const Duration(minutes: 3, seconds: 59));
    await reminders.sync();
    expect(reminders.dueCount.value, 0);
    now = start.add(const Duration(minutes: 4));
    await reminders.refreshBadge();
    expect(reminders.dueCount.value, 1);
    await reminders.acknowledgeHistory();
    expect(reminders.dueCount.value, 0);
    expect(await user.attempts((await user.sessions()).single.id), isEmpty);
  });

  test(
    'review alarms are replaced after recall and removed when disabled',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final scheduled = <Object?, Map<dynamic, dynamic>>{};
      var permissionRequests = 0;
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'initialize':
                return true;
              case 'getNotificationAppLaunchDetails':
                return {'notificationLaunchedApp': false};
              case 'requestNotificationsPermission':
                permissionRequests++;
                return true;
              case 'cancelAll':
                scheduled.clear();
                return null;
              case 'zonedSchedule':
                final args = call.arguments as Map<dynamic, dynamic>;
                scheduled[args['id']] = args;
                return null;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final user = UserDatabase(NativeDatabase.memory());
      addTearDown(user.close);
      final reminders = ReviewReminders(user);
      addTearDown(reminders.dispose);
      final now = DateTime.now();
      await user.saveReviewSettings(
        ReviewSettings(
          intervals: [const Duration(minutes: 1), const Duration(minutes: 2)],
          adaptive: false,
        ),
      );
      await user.completePortion(Riwayah.hafs, [1, 2], now);
      await reminders.initialize();
      expect(scheduled, isEmpty);
      expect(await reminders.setEnabled(true), isTrue);
      expect(permissionRequests, 1);
      expect(scheduled.length, 2);
      expect(
        scheduled.values.every((s) => s['title'] == 'حان وقت تثبيت الحفظ'),
        isTrue,
      );
      final session = (await user.sessions()).single;
      await user.recordRecall(
        session.id,
        0,
        RecallRating.good,
        now.add(const Duration(minutes: 1)),
      );
      await reminders.sync();
      expect(scheduled.length, 1);
      await reminders.setEnabled(false);
      expect(scheduled, isEmpty);
    },
  );
}
