import '../entities/savings_goal.dart';

abstract class GoalRepository {
  Future<List<SavingsGoal>> load();

  Future<void> save(List<SavingsGoal> goals);
}
