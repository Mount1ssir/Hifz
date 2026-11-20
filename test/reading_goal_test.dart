import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/core/data/user_database.dart';

void main() {
  test('open goals count overlapping passages once and retain the first unread ayah', () async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.createReadingGoal('مراجعة', false, [1, 2, 3, 4, 5], 0, 1);
    var goal = (await db.readingGoals()).single;
    expect(goal.due(goal.startDay + 3), 0);
    await db.logGoalRange(goal, 4, 5);
    goal = (await db.readingGoals()).single;
    expect(goal.unread, [1, 2, 3]);
    await db.logGoalRange(goal, 2, 4);
    goal = (await db.readingGoals()).single;
    expect(goal.read, 4);
    expect(goal.unread, [1]);
    expect((await db.goalHistory(goal.id)).first.$2, 2);
  });

  test('deleting one goal removes only its reading history', () async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final name in ['الأول', 'الثاني']) {
      await db.createReadingGoal(name, false, [1, 2], 0, 1);
    }
    final goals = await db.readingGoals();
    for (final goal in goals) {
      await db.logGoalRange(goal, 1, 1);
    }
    await db.deleteReadingGoal(goals.first.id);
    expect((await db.readingGoals()).single.id, goals.last.id);
    expect(await db.goalHistory(goals.first.id), isEmpty);
    expect(await db.goalHistory(goals.last.id), hasLength(1));
  });

  test(
    'missed portions carry forward and partial logs advance the next page',
    () async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.createReadingGoal('هدف', true, [1, 8, 13, 25, 34], 2, 1);
      var g = (await db.readingGoals()).single;
      expect(g.due(g.startDay + 1), 4);
      await db.logGoalReading(g, 3);
      await expectLater(db.logGoalReading(g, 1), throwsStateError);
      g = (await db.readingGoals()).single;
      expect(g.due(g.startDay + 1), 1);
      expect(g.anchors[g.read], 25);
      expect((await db.goalHistory(g.id)).single.$2, 3);
      await db.logGoalReading(g, 2);
      expect((await db.readingGoals()).single.remaining, 0);
    },
  );
}
