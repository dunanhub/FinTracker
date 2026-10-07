import '../entities/app_notification.dart';
import '../entities/debt.dart';
import '../entities/savings_goal.dart';

class ReminderPolicy {
  const ReminderPolicy._();

  static DateTime remindAt(DateTime deadline) =>
      DateTime(deadline.year, deadline.month, deadline.day - 1, 9);

  static List<AppNotification> upcoming({
    required List<Debt> debts,
    required List<SavingsGoal> goals,
    required DateTime now,
  }) {
    final result = <AppNotification>[];
    for (final debt in debts) {
      final deadline = debt.deadline;
      if (deadline == null || debt.isPaid) continue;
      final at = remindAt(deadline);
      if (!at.isAfter(now)) continue;
      result.add(
        AppNotification(
          id: 'reminder:debt:${debt.id}:${_dateKey(deadline)}',
          kind: AppNotificationKind.debt,
          entityId: debt.id,
          title: 'Срок долга завтра',
          body: 'Долг: ${debt.person}',
          scheduledAt: at,
        ),
      );
    }
    for (final goal in goals) {
      if (goal.currentAmount >= goal.targetAmount) continue;
      final at = remindAt(goal.deadline);
      if (!at.isAfter(now)) continue;
      result.add(
        AppNotification(
          id: 'reminder:goal:${goal.id}:${_dateKey(goal.deadline)}',
          kind: AppNotificationKind.goal,
          entityId: goal.id,
          title: 'Срок цели завтра',
          body: 'Цель: ${goal.name}',
          scheduledAt: at,
        ),
      );
    }
    result.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return result;
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static int notificationId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
