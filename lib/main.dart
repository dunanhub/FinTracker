import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'data/repositories/firebase_auth_repository.dart';
import 'data/repositories/firebase_receipt_storage_repository.dart';
import 'data/repositories/firebase_push_notification_repository.dart';
import 'data/repositories/firebase_user_profile_repository.dart';
import 'data/repositories/hive_budget_repository.dart';
import 'data/repositories/hive_debt_repository.dart';
import 'data/repositories/hive_finance_repository.dart';
import 'data/repositories/hive_goal_repository.dart';
import 'data/repositories/hive_notification_repository.dart';
import 'data/services/local_notification_scheduler.dart';
import 'data/services/crash_reporting_service.dart';
import 'data/sync/firebase_sync_repository.dart';
import 'firebase_options.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/controllers/budget_controller.dart';
import 'presentation/controllers/debt_controller.dart';
import 'presentation/controllers/finance_controller.dart';
import 'presentation/controllers/goal_controller.dart';
import 'presentation/controllers/notification_center_controller.dart';
import 'presentation/controllers/push_notification_controller.dart';
import 'presentation/controllers/shake_settings_controller.dart';
import 'presentation/controllers/sync_controller.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('FinTracker background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final crashReporting = CrashReportingService();
  await crashReporting.initialize();
  crashReporting.installGlobalHandlers();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Hive.initFlutter();

  final themeController = ThemeController();

  await themeController.load();

  final shakeSettingsController = ShakeSettingsController();
  await shakeSettingsController.load();

  final financeRepository = HiveFinanceRepository();

  await financeRepository.init();

  final budgetRepository = HiveBudgetRepository();

  await budgetRepository.init();

  final goalRepository = HiveGoalRepository();

  await goalRepository.init();

  final debtRepository = HiveDebtRepository();

  await debtRepository.init();

  final financeController = FinanceController(repository: financeRepository);

  await financeController.load();

  final budgetController = BudgetController(repository: budgetRepository);

  await budgetController.load();

  final goalController = GoalController(repository: goalRepository);

  await goalController.load();

  final debtController = DebtController(repository: debtRepository);

  await debtController.load();

  final authController = AuthController(
    repository: FirebaseAuthRepository(),
    profileRepository: FirebaseUserProfileRepository(),
  );

  final syncController = SyncController(
    authController: authController,
    financeController: financeController,
    budgetController: budgetController,
    goalController: goalController,
    debtController: debtController,
    financeRepository: financeRepository,
    budgetRepository: budgetRepository,
    goalRepository: goalRepository,
    debtRepository: debtRepository,
    cloudRepository: FirebaseSyncRepository(),
    receiptStorageRepository: FirebaseReceiptStorageRepository(),
  );

  await syncController.start();

  final notificationCenter = NotificationCenterController(
    authController: authController,
    debtController: debtController,
    goalController: goalController,
    syncController: syncController,
    repository: HiveNotificationRepository(),
    scheduler: LocalNotificationScheduler(),
  );
  await notificationCenter.start();

  final pushController = PushNotificationController(
    authController: authController,
    repository: FirebasePushNotificationRepository(),
    notificationCenter: notificationCenter,
  );

  await pushController.start();

  runApp(
    FinTrackerApp(
      themeController: themeController,
      financeController: financeController,
      budgetController: budgetController,
      goalController: goalController,
      debtController: debtController,
      authController: authController,
      syncController: syncController,
      pushController: pushController,
      notificationCenter: notificationCenter,
      shakeSettingsController: shakeSettingsController,
      crashReporting: crashReporting,
    ),
  );
}
