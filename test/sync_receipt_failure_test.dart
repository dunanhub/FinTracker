import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fin_tracker/data/repositories/hive_budget_repository.dart';
import 'package:fin_tracker/data/repositories/hive_debt_repository.dart';
import 'package:fin_tracker/data/repositories/hive_finance_repository.dart';
import 'package:fin_tracker/data/repositories/hive_goal_repository.dart';
import 'package:fin_tracker/data/services/receipt_image_service.dart';
import 'package:fin_tracker/data/sync/firebase_sync_repository.dart';
import 'package:fin_tracker/domain/entities/account.dart';
import 'package:fin_tracker/domain/entities/app_user.dart';
import 'package:fin_tracker/domain/entities/finance_transaction.dart';
import 'package:fin_tracker/domain/repositories/auth_repository.dart';
import 'package:fin_tracker/domain/repositories/receipt_storage_repository.dart';
import 'package:fin_tracker/domain/repositories/user_profile_repository.dart';
import 'package:fin_tracker/presentation/controllers/auth_controller.dart';
import 'package:fin_tracker/presentation/controllers/budget_controller.dart';
import 'package:fin_tracker/presentation/controllers/debt_controller.dart';
import 'package:fin_tracker/presentation/controllers/finance_controller.dart';
import 'package:fin_tracker/presentation/controllers/goal_controller.dart';
import 'package:fin_tracker/presentation/controllers/sync_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _uid = 'test_user';
const _oldPath = 'users/$_uid/receipts/tx_1/receipt-1.jpg';
const _newPath = 'users/$_uid/receipts/tx_1/receipt-2.jpg';

const _account = Account(
  id: 'cash',
  name: 'Наличные',
  type: AccountType.cash,
  balance: 100,
);

final _transaction = FinanceTransaction(
  id: 'tx_1',
  type: FinanceTransactionType.expense,
  amount: 25,
  accountId: 'cash',
  title: 'Покупка',
  date: DateTime(2026, 10, 5),
  receiptPath: 'local/receipt.jpg',
);

class _UnusedFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected Firestore SDK call');
}

class _FakeCloudRepository extends FirebaseSyncRepository {
  _FakeCloudRepository() : super(firestore: _UnusedFirestore());

  SyncData? downloaded;
  SyncData? uploaded;
  int uploadCalls = 0;

  @override
  Future<SyncData?> download(String uid) async => downloaded;

  @override
  Future<void> upload({
    required String uid,
    required SyncData data,
    required String deviceId,
  }) async {
    uploadCalls++;
    uploaded = data;
  }

  @override
  Stream<SyncMeta?> watchMeta(String uid) => const Stream.empty();

  @override
  Future<Set<String>> receiptPathsFromServer(String uid) async => {
    for (final tx in uploaded?.transactions ?? <FinanceTransaction>[])
      if (tx.receiptStoragePath != null) tx.receiptStoragePath!,
  };
}

class _FakeReceiptStorage implements ReceiptStorageRepository {
  bool failUpload = true;
  final deleted = <String>[];

  @override
  Future<String> upload({
    required String uid,
    required String transactionId,
    required String localPath,
  }) async {
    if (failUpload) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'object-not-found',
      );
    }
    return _newPath;
  }

  @override
  Future<String> download({
    required String uid,
    required String transactionId,
    required String storagePath,
  }) async => throw StateError('Unexpected download');

  @override
  Future<void> delete({
    required String uid,
    required String storagePath,
  }) async {
    deleted.add(storagePath);
  }
}

class _FakeReceiptImageService extends ReceiptImageService {
  @override
  Future<bool> existsLocally(String? path) async => path != null;
}

class _FakeAuthRepository implements AuthRepository {
  @override
  AppUser? get currentUser => const AppUser(uid: _uid);

  @override
  Stream<AppUser?> authStateChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected auth call');
}

class _FakeProfileRepository implements UserProfileRepository {
  @override
  Future<void> saveProfile(AppUser user) async {}
}

Future<(SyncController, _FakeCloudRepository, _FakeReceiptStorage)> _setup({
  String? oldStoragePath,
}) async {
  SharedPreferences.setMockInitialValues({
    if (oldStoragePath != null) 'fintracker_sync_pending_$_uid': true,
  });
  final directory = await Directory.systemTemp.createTemp(
    'fintracker_sync_test_',
  );
  Hive.init(directory.path);
  addTearDown(() async {
    await Hive.close();
    final root = Directory.systemTemp.absolute.path.toLowerCase();
    final target = directory.absolute.path.toLowerCase();
    if (!target.startsWith(
      '$root${Platform.pathSeparator}fintracker_sync_test_',
    )) {
      throw StateError('Unexpected test directory');
    }
    await directory.delete(recursive: true);
  });

  final financeRepository = HiveFinanceRepository();
  await financeRepository.init(scope: _uid);
  await financeRepository.save(
    transactions: [_transaction],
    accounts: [_account],
  );
  await financeRepository.switchScope('legacy');

  final budgetRepository = HiveBudgetRepository();
  await budgetRepository.init();
  final goalRepository = HiveGoalRepository();
  await goalRepository.init();
  final debtRepository = HiveDebtRepository();
  await debtRepository.init();

  final auth = AuthController(
    repository: _FakeAuthRepository(),
    profileRepository: _FakeProfileRepository(),
  );
  final cloud = _FakeCloudRepository();
  if (oldStoragePath != null) {
    cloud.downloaded = SyncData(
      accounts: const [_account],
      transactions: [_transaction.copyWith(receiptStoragePath: oldStoragePath)],
      budgets: const [],
      goals: const [],
      debts: const [],
    );
  }
  final receipts = _FakeReceiptStorage();
  final sync = SyncController(
    authController: auth,
    financeController: FinanceController(repository: financeRepository),
    budgetController: BudgetController(repository: budgetRepository),
    goalController: GoalController(repository: goalRepository),
    debtController: DebtController(repository: debtRepository),
    financeRepository: financeRepository,
    budgetRepository: budgetRepository,
    goalRepository: goalRepository,
    debtRepository: debtRepository,
    cloudRepository: cloud,
    receiptStorageRepository: receipts,
    receiptImageService: _FakeReceiptImageService(),
  );
  addTearDown(() {
    sync.dispose();
    auth.dispose();
  });
  await sync.start();
  return (sync, cloud, receipts);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Storage 404 does not block Firestore data; manual retry uploads receipt',
    () async {
      final (sync, cloud, receipts) = await _setup();

      expect(cloud.uploadCalls, 1);
      expect(cloud.uploaded?.transactions.single.title, 'Покупка');
      expect(cloud.uploaded?.transactions.single.receiptStoragePath, isNull);
      expect(sync.status, SyncStatus.error);

      receipts.failUpload = false;
      await sync.syncNow();

      expect(cloud.uploadCalls, 2);
      expect(cloud.uploaded?.transactions.single.receiptStoragePath, _newPath);
      expect(sync.status, SyncStatus.synced);
    },
  );

  test(
    'failed replacement retains old cloud receipt until new upload succeeds',
    () async {
      final (sync, cloud, receipts) = await _setup(oldStoragePath: _oldPath);

      expect(cloud.uploaded?.transactions.single.receiptStoragePath, _oldPath);
      expect(receipts.deleted, isEmpty);

      receipts.failUpload = false;
      await sync.syncNow();

      expect(cloud.uploaded?.transactions.single.receiptStoragePath, _newPath);
      expect(receipts.deleted, contains(_oldPath));
    },
  );
}
