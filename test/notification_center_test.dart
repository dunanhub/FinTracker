import 'dart:io';

import 'package:fin_tracker/data/repositories/hive_notification_repository.dart';
import 'package:fin_tracker/data/services/local_notification_scheduler.dart';
import 'package:fin_tracker/domain/entities/app_notification.dart';
import 'package:fin_tracker/domain/entities/app_user.dart';
import 'package:fin_tracker/domain/entities/debt.dart';
import 'package:fin_tracker/domain/entities/savings_goal.dart';
import 'package:fin_tracker/domain/services/reminder_policy.dart';
import 'package:fin_tracker/presentation/controllers/auth_controller.dart';
import 'package:fin_tracker/presentation/controllers/debt_controller.dart';
import 'package:fin_tracker/presentation/controllers/goal_controller.dart';
import 'package:fin_tracker/presentation/controllers/notification_center_controller.dart';
import 'package:fin_tracker/presentation/controllers/push_notification_controller.dart';
import 'package:fin_tracker/presentation/controllers/sync_controller.dart';
import 'package:fin_tracker/presentation/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

class _Auth extends ChangeNotifier implements AuthController {
  AppUser? current = const AppUser(uid: 'alice');
  @override
  AppUser? get user => current;
  void switchTo(String? uid) {
    current = uid == null ? null : AppUser(uid: uid);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sync extends ChangeNotifier implements SyncController {
  @override
  bool get isSyncing => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Push extends ChangeNotifier implements PushNotificationController {
  @override
  bool get isEnabled => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Scheduler implements NotificationScheduler {
  final active = <String, AppNotification>{};
  final cancelled = <String>[];
  @override
  Future<String?> initialize(void Function(String) onTap) async => null;
  @override
  Future<void> refreshTimezone() async {}
  @override
  Future<void> schedule(AppNotification notification) async {
    active[notification.id] = notification;
  }

  @override
  Future<void> cancel(String id) async {
    active.remove(id);
    cancelled.add(id);
  }
}

class _MemoryRepository extends HiveNotificationRepository {
  final boxes = <String, List<AppNotification>>{};
  String scope = '';
  @override
  Future<void> switchScope(String uid) async {
    scope = uid;
  }

  @override
  Future<List<AppNotification>> load() async => List.of(boxes[scope] ?? []);
  @override
  Future<void> save(List<AppNotification> items) async {
    boxes[scope] = List.of(items);
  }
}

void main() {
  test('reminds one day before at 09:00 and excludes finished records', () {
    final deadline = DateTime(2026, 10, 10, 16);
    final now = DateTime(2026, 10, 8);
    final dueDebt = Debt(
      id: 'd1',
      type: DebtType.iOwe,
      person: 'Anna',
      originalAmount: 100,
      remainingAmount: 50,
      deadline: deadline,
      createdAt: now,
    );
    final paidDebt = dueDebt.copyWith(id: 'd2', remainingAmount: 0);
    final goal = SavingsGoal(
      id: 'g1',
      name: 'Дом',
      targetAmount: 100,
      currentAmount: 20,
      deadline: deadline,
      createdAt: now,
    );
    final doneGoal = goal.copyWith(id: 'g2', currentAmount: 100);
    final result = ReminderPolicy.upcoming(
      debts: [dueDebt, paidDebt],
      goals: [goal, doneGoal],
      now: now,
    );
    expect(result.length, 2);
    expect(
      result.map((item) => item.kind),
      containsAll([AppNotificationKind.debt, AppNotificationKind.goal]),
    );
    expect(result.first.scheduledAt, DateTime(2026, 10, 9, 9));
    expect(
      ReminderPolicy.upcoming(
        debts: [dueDebt],
        goals: [goal],
        now: DateTime(2026, 10, 9, 9),
      ),
      isEmpty,
    );
  });

  test('Hive history stays separate for each user', () async {
    final dir = await Directory.systemTemp.createTemp(
      'fintracker-notification-',
    );
    Hive.init(dir.path);
    try {
      final repo = HiveNotificationRepository();
      await repo.switchScope('alice');
      await repo.save([
        AppNotification(
          id: 'a',
          kind: AppNotificationKind.push,
          title: 'A',
          body: 'B',
          scheduledAt: DateTime(2026, 1, 1),
        ),
      ]);
      await repo.switchScope('bob');
      expect(await repo.load(), isEmpty);
      await repo.switchScope('alice');
      expect((await repo.load()).single.id, 'a');
    } finally {
      await Hive.close();
      await dir.delete(recursive: true);
    }
  });

  testWidgets(
    'reschedules changed deadlines, cancels paid debts and clears on logout',
    (tester) async {
      final auth = _Auth();
      final debts = DebtController();
      final goals = GoalController();
      final scheduler = _Scheduler();
      final center = NotificationCenterController(
        authController: auth,
        debtController: debts,
        goalController: goals,
        syncController: _Sync(),
        repository: _MemoryRepository(),
        scheduler: scheduler,
      );
      await center.start();
      final tomorrow = DateTime.now().add(const Duration(days: 5));
      await debts.addDebt(
        type: DebtType.iOwe,
        person: 'Anna',
        amount: 100,
        deadline: tomorrow,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(scheduler.active.length, 1);
      final id = debts.debts.single.id;
      final oldKey = scheduler.active.keys.single;
      await debts.updateDebt(
        id: id,
        type: DebtType.iOwe,
        person: 'Anna',
        amount: 100,
        deadline: tomorrow.add(const Duration(days: 2)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(scheduler.cancelled, contains(oldKey));
      expect(scheduler.active.length, 1);
      await debts.addPayment(debtId: id, amount: 100);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(scheduler.active, isEmpty);

      await goals.addGoal(
        name: 'Дом',
        targetAmount: 100,
        currentAmount: 0,
        deadline: tomorrow,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(scheduler.active.length, 1);
      auth.switchTo(null);
      await tester.pump();
      await tester.pump();
      expect(scheduler.active, isEmpty);
      expect(center.items, isEmpty);
      center.dispose();
    },
  );

  testWidgets('deduplicates FCM messages and holds tapped destination', (
    tester,
  ) async {
    final center = NotificationCenterController(
      authController: _Auth(),
      debtController: DebtController(),
      goalController: GoalController(),
      syncController: _Sync(),
      repository: _MemoryRepository(),
      scheduler: _Scheduler(),
    );
    await center.start();
    await center.recordPush(
      id: 'fcm-1',
      title: 'Test',
      body: 'Message',
      data: const {},
      opened: false,
    );
    await center.recordPush(
      id: 'fcm-1',
      title: 'Test',
      body: 'Message',
      data: const {},
      opened: true,
    );
    expect(center.items.length, 1);
    expect(center.takePendingNavigation(), 'push:fcm-1');
    expect(center.takePendingNavigation(), isNull);
    await center.markRead('push:fcm-1');
    expect(center.unreadCount, 0);
    center.dispose();
  });

  testWidgets('tapping a debt notification opens its details', (tester) async {
    final now = DateTime.now();
    final debts = DebtController();
    await debts.addDebt(
      type: DebtType.iOwe,
      person: 'Anna',
      amount: 100,
      deadline: now.add(const Duration(days: 5)),
    );
    final id = debts.debts.single.id;
    final repo = _MemoryRepository();
    repo.boxes['alice'] = [
      AppNotification(
        id: 'old-debt',
        kind: AppNotificationKind.debt,
        title: 'Срок долга завтра',
        body: 'Долг: Anna',
        entityId: id,
        scheduledAt: now.subtract(const Duration(days: 1)),
      ),
    ];
    final center = NotificationCenterController(
      authController: _Auth(),
      debtController: debts,
      goalController: GoalController(),
      syncController: _Sync(),
      repository: repo,
      scheduler: _Scheduler(),
    );
    await center.start();
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/debts/:id',
          builder:
              (_, state) =>
                  Scaffold(body: Text('Долг ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NotificationCenterController?>.value(
            value: center,
          ),
          ChangeNotifierProvider<PushNotificationController>.value(
            value: _Push(),
          ),
          ChangeNotifierProvider<DebtController>.value(value: debts),
          ChangeNotifierProvider<GoalController>.value(value: GoalController()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Срок долга завтра'));
    await tester.pumpAndSettle();
    expect(find.text('Долг $id'), findsOneWidget);
    expect(center.unreadCount, 0);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    center.dispose();
  });
}
