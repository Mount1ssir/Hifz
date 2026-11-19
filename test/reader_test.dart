import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hifz/core/data/quran_repository.dart';
import 'package:hifz/domain/review_scheduler.dart';
import 'package:hifz/features/quran_reader.dart';

void main() {
  const ayahs = [
    QuranAyah(
      id: 1,
      surah: 1,
      number: 1,
      text: 'First test text',
      basmalahPrefix: '',
      page: 1,
      juz: 1,
    ),
    QuranAyah(
      id: 2,
      surah: 1,
      number: 2,
      text: 'Second test text',
      basmalahPrefix: '',
      page: 1,
      juz: 1,
    ),
  ];

  testWidgets('recall cards conceal text and save only after comparison', (
    tester,
  ) async {
    RecallRating? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: QuranReader(
          ayahs: ayahs,
          title: 'Recall',
          initialMode: ReaderMode.cards,
          startHidden: true,
          onRecall: (rating) async {
            saved = rating;
          },
        ),
      ),
    );
    expect(find.text('First test text'), findsNothing);
    expect(find.text('Good'), findsNothing);
    await tester.ensureVisible(find.text('Reveal ayah'));
    await tester.tap(find.text('Reveal ayah'));
    await tester.pump();
    expect(find.text('First test text'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('Second test text'), findsNothing);
    expect(find.text('Good'), findsNothing);
    await tester.ensureVisible(find.text('Reveal ayah'));
    await tester.tap(find.text('Reveal ayah'));
    await tester.pump();
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    expect(saved, RecallRating.good);
  });

  testWidgets('empty portions show an explicit message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QuranReader(ayahs: [], title: 'Reader'),
      ),
    );
    expect(find.text('No ayahs in this portion.'), findsOneWidget);
  });
}
