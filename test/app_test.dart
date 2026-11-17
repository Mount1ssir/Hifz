import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app_modules.dart';

void main() {
  testWidgets('starts on the Hifz screen', (tester) async {
    await tester.pumpWidget(const HifzApp());

    expect(find.text('Hifz'), findsOneWidget);
  });
}
