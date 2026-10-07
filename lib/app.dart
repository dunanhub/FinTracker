import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/services/crash_reporting_service.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/controllers/budget_controller.dart';
import 'presentation/controllers/debt_controller.dart';
import 'presentation/controllers/finance_controller.dart';
import 'presentation/controllers/goal_controller.dart';
import 'presentation/controllers/notification_center_controller.dart';
import 'presentation/controllers/push_notification_controller.dart';
import 'presentation/controllers/shake_settings_controller.dart';
import 'presentation/controllers/sync_controller.dart';

class FinTrackerApp extends StatelessWidget {
  final ThemeController themeController;

  final FinanceController financeController;

  final BudgetController? budgetController;

  final GoalController? goalController;

  final DebtController? debtController;

  final AuthController? authController;

  final SyncController? syncController;

  final PushNotificationController? pushController;
  final NotificationCenterController? notificationCenter;
  final ShakeSettingsController? shakeSettingsController;
  final CrashReportingService? crashReporting;

  const FinTrackerApp({
    super.key,
    required this.themeController,
    required this.financeController,
    this.budgetController,
    this.goalController,
    this.debtController,
    this.authController,
    this.syncController,
    this.pushController,
    this.notificationCenter,
    this.shakeSettingsController,
    this.crashReporting,
  });

  @override
  Widget build(BuildContext context) {
    return riverpod.ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeController>.value(value: themeController),
          ChangeNotifierProvider<FinanceController>.value(
            value: financeController,
          ),
          ChangeNotifierProvider<BudgetController>.value(
            value: budgetController ?? BudgetController(),
          ),
          ChangeNotifierProvider<GoalController>.value(
            value: goalController ?? GoalController(),
          ),
          ChangeNotifierProvider<DebtController>.value(
            value: debtController ?? DebtController(),
          ),
          if (authController != null)
            ChangeNotifierProvider<AuthController>.value(
              value: authController!,
            ),
          if (syncController != null)
            ChangeNotifierProvider<SyncController>.value(
              value: syncController!,
            ),
          if (pushController != null)
            ChangeNotifierProvider<PushNotificationController>.value(
              value: pushController!,
            ),
          ChangeNotifierProvider<NotificationCenterController?>.value(
            value: notificationCenter,
          ),
          if (shakeSettingsController == null)
            ChangeNotifierProvider<ShakeSettingsController>(
              create: (_) => ShakeSettingsController(),
            )
          else
            ChangeNotifierProvider<ShakeSettingsController>.value(
              value: shakeSettingsController!,
            ),
          Provider<CrashReportingService?>.value(value: crashReporting),
        ],
        child: _FinTrackerView(
          authController: authController,
          notificationCenter: notificationCenter,
        ),
      ),
    );
  }
}

class _FinTrackerView extends StatefulWidget {
  final AuthController? authController;
  final NotificationCenterController? notificationCenter;

  const _FinTrackerView({
    required this.authController,
    required this.notificationCenter,
  });

  @override
  State<_FinTrackerView> createState() => _FinTrackerViewState();
}

class _FinTrackerViewState extends State<_FinTrackerView> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _router = AppRouter.create(authController: widget.authController);
    widget.notificationCenter?.addListener(_openPendingNotification);
    widget.authController?.addListener(_openPendingNotification);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openPendingNotification(),
    );
  }

  void _openPendingNotification() {
    if (!mounted || widget.authController?.isAuthenticated != true) return;
    final id = widget.notificationCenter?.takePendingNavigation();
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.authController?.isAuthenticated == true) {
        _router.go('/notifications?open=${Uri.encodeQueryComponent(id)}');
      }
    });
  }

  @override
  void dispose() {
    widget.notificationCenter?.removeListener(_openPendingNotification);
    widget.authController?.removeListener(_openPendingNotification);
    _router.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();

    return MaterialApp.router(
      title: 'FinTracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(controller.preset),
      darkTheme: AppTheme.dark(controller.preset),
      themeMode: controller.themeMode,
      routerConfig: _router,
    );
  }
}
