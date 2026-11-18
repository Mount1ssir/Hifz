import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app_modules.dart';
import 'package:hifz/core/data/app_databases.dart';

void main() {
  testWidgets('shows loading and a retry action when startup fails', (
    tester,
  ) async {
    final opening = Completer<AppDatabases>();
    await tester.pumpWidget(HifzApp(openDatabases: () => opening.future));
    expect(find.text('Hifz'), findsOneWidget);
    expect(find.text('Opening your Quran…'), findsOneWidget);
    opening.completeError(StateError('Unavailable database'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
  });
}
