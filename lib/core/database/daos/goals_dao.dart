import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'goals_dao.g.dart';

@DriftAccessor(tables: [Goals])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.db);

  Stream<List<Goal>> watchActiveGoals() {
    return (select(goals)..where((g) => g.status.equals('active'))).watch();
  }

  Future<int> createGoal(Insertable<Goal> goal) {
    return into(goals).insert(goal);
  }

  Future<bool> updateGoalAmount(String goalId, double addAmount) async {
    final goal = await (select(goals)..where((g) => g.id.equals(goalId))).getSingle();
    return update(goals).replace(
      goal.copyWith(currentAmount: goal.currentAmount + addAmount)
    );
  }

  Future<bool> updateGoal(Insertable<Goal> goal) {
    return update(goals).replace(goal);
  }
}
