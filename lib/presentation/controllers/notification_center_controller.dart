import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/repositories/hive_notification_repository.dart';
import '../../data/services/local_notification_scheduler.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/services/reminder_policy.dart';
import 'auth_controller.dart';
import 'debt_controller.dart';
import 'goal_controller.dart';
import 'sync_controller.dart';

class NotificationCenterController extends ChangeNotifier
    with WidgetsBindingObserver {
  final AuthController authController;
  final DebtController debtController;
  final GoalController goalController;
  final SyncController syncController;
  final HiveNotificationRepository repository;
  final NotificationScheduler scheduler;

  NotificationCenterController({
    required this.authController,
    required this.debtController,
    required this.goalController,
    required this.syncController,
    required this.repository,
    required this.scheduler,
  });

  String? _uid;
  List<AppNotification> _items = [];
  String? _pendingNavigationId;
  String? _error;
  Timer? _reconcileTimer;
  Timer? _dueTimer;
  Future<void> _work = Future<void>.value();
  bool _started = false;

  String? get error => _error;
  List<AppNotification> get items {
    final now = DateTime.now();
    final visible =
        _items.where((item) => !item.scheduledAt.isAfter(now)).toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return List.unmodifiable(visible);
  }

  int get unreadCount => items.where((item) => !item.isRead).length;
  AppNotification? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  String? takePendingNavigation() {
    final value = _pendingNavigationId;
    _pendingNavigationId = null;
    return value;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    authController.addListener(_onAuthChanged);
    debtController.addListener(_queueReconcile);
    goalController.addListener(_queueReconcile);
    syncController.addListener(_queueReconcile);
    try {
      final launchId = await scheduler.initialize(_onNotificationTap);
      if (launchId != null) _pendingNavigationId = launchId;
    } catch (error) {
      _error = 'Не удалось настроить напоминания: $error';
    }
    await _switchUser(authController.user?.uid);
  }

  void _onNotificationTap(String id) {
    _pendingNavigationId = id;
    notifyListeners();
  }

  void _onAuthChanged() {
    final next = authController.user?.uid;
    if (next == _uid) return;
    _enqueue(() => _switchUser(next));
  }

  Future<void> _switchUser(String? next) async {
    if (next == _uid) return;
    _reconcileTimer?.cancel();
    _dueTimer?.cancel();
    for (final item in _items) {
      if (item.kind != AppNotificationKind.push) {
        try {
          await scheduler.cancel(item.id);
        } catch (error) {
          _error = 'Не удалось отменить напоминание: $error';
        }
      }
    }
    _uid = next;
    _items = [];
    notifyListeners();
    if (next == null) return;
    await repository.switchScope(next);
    _items = await repository.load();
    notifyListeners();
    _queueReconcile(force: true);
  }

  void _queueReconcile({bool force = false}) {
    if (_uid == null) return;
    _reconcileTimer?.cancel();
    _reconcileTimer = Timer(const Duration(milliseconds: 250), () {
      _enqueue(() => _reconcile(force: force));
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    _work = _work.then((_) => action()).catchError((Object error) {
      _error = 'Не удалось обновить напоминания: $error';
      notifyListeners();
    });
    return _work;
  }

  Future<void> _reconcile({bool force = false}) async {
    final uid = _uid;
    if (uid == null ||
        uid != authController.user?.uid ||
        syncController.isSyncing) {
      return;
    }
    final now = DateTime.now();
    if (force) await scheduler.refreshTimezone();
    _error = null;
    final desired =
        ReminderPolicy.upcoming(
          debts: debtController.debts,
          goals: goalController.goals,
          now: now,
        ).take(400).toList();
    final wanted = {for (final item in desired) item.id: item};
    final previous = {for (final item in _items) item.id: item};
    final nextItems = <AppNotification>[];
    for (final item in _items) {
      if (item.kind == AppNotificationKind.push ||
          !item.scheduledAt.isAfter(now)) {
        nextItems.add(item);
      } else if (!wanted.containsKey(item.id)) {
        await scheduler.cancel(item.id);
      }
    }
    for (final item in desired) {
      final old = previous[item.id];
      if (force ||
          old == null ||
          old.title != item.title ||
          old.body != item.body) {
        if (old != null) await scheduler.cancel(item.id);
        try {
          await scheduler.schedule(item);
        } catch (error) {
          _error = 'Не удалось запланировать напоминание: $error';
          continue;
        }
      }
      nextItems.add(item);
    }
    if (uid != _uid) return;
    _items = nextItems;
    await repository.save(_items);
    _armDueTimer();
    notifyListeners();
  }

  void _armDueTimer() {
    _dueTimer?.cancel();
    final upcoming =
        _items
            .where(
              (item) =>
                  item.kind != AppNotificationKind.push &&
                  item.scheduledAt.isAfter(DateTime.now()),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (upcoming.isEmpty) return;
    final delay = upcoming.first.scheduledAt.difference(DateTime.now());
    _dueTimer = Timer(delay + const Duration(seconds: 1), () {
      notifyListeners();
      _armDueTimer();
    });
  }

  Future<void> markRead(String id) => _enqueue(() async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || _items[index].isRead) return;
    _items[index] = _items[index].copyWith(isRead: true);
    notifyListeners();
    await repository.save(_items);
  });

  Future<void> recordPush({
    required String id,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required bool opened,
  }) => _enqueue(() async {
    if (_uid == null) return;
    final kind = switch (data['type']) {
      'debt' => AppNotificationKind.debt,
      'goal' => AppNotificationKind.goal,
      _ => AppNotificationKind.push,
    };
    final entityId = data['entityId']?.toString();
    final key = 'push:$id';
    if (!_items.any((item) => item.id == key)) {
      _items.add(
        AppNotification(
          id: key,
          kind: kind,
          title: title,
          body: body,
          entityId: entityId,
          scheduledAt: DateTime.now(),
        ),
      );
      await repository.save(_items);
    }
    if (opened) _pendingNavigationId = key;
    notifyListeners();
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _queueReconcile(force: true);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    authController.removeListener(_onAuthChanged);
    debtController.removeListener(_queueReconcile);
    goalController.removeListener(_queueReconcile);
    syncController.removeListener(_queueReconcile);
    _reconcileTimer?.cancel();
    _dueTimer?.cancel();
    super.dispose();
  }
}
