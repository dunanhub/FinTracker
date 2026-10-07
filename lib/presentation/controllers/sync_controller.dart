import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/hive_budget_repository.dart';
import '../../data/repositories/hive_debt_repository.dart';
import '../../data/repositories/hive_finance_repository.dart';
import '../../data/repositories/hive_goal_repository.dart';
import '../../data/services/receipt_image_service.dart';
import '../../data/sync/firebase_sync_repository.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/repositories/receipt_storage_repository.dart';
import 'auth_controller.dart';
import 'budget_controller.dart';
import 'debt_controller.dart';
import 'finance_controller.dart';
import 'goal_controller.dart';

enum SyncStatus { idle, syncing, synced, offline, error }

class SyncController extends ChangeNotifier {
  static const String _deviceIdKey = 'fintracker_sync_device_id';

  static const String _legacyClaimKey = 'fintracker_legacy_claim_uid';
  static const String _pendingKeyPrefix = 'fintracker_sync_pending_';
  static const String _deleteKeyPrefix = 'fintracker_receipt_deletes_';

  final AuthController authController;

  final FinanceController financeController;

  final BudgetController budgetController;

  final GoalController goalController;

  final DebtController debtController;

  final HiveFinanceRepository financeRepository;

  final HiveBudgetRepository budgetRepository;

  final HiveGoalRepository goalRepository;

  final HiveDebtRepository debtRepository;

  final FirebaseSyncRepository cloudRepository;
  final ReceiptStorageRepository receiptStorageRepository;
  final ReceiptImageService _receiptImageService;

  SyncController({
    required this.authController,
    required this.financeController,
    required this.budgetController,
    required this.goalController,
    required this.debtController,
    required this.financeRepository,
    required this.budgetRepository,
    required this.goalRepository,
    required this.debtRepository,
    required this.cloudRepository,
    required this.receiptStorageRepository,
    ReceiptImageService? receiptImageService,
  }) : _receiptImageService = receiptImageService ?? ReceiptImageService();

  SyncStatus _status = SyncStatus.idle;

  DateTime? _lastSyncAt;

  String? _message;

  String? _activeUid;

  String? _deviceId;

  bool _started = false;

  bool _busy = false;

  bool _suspendLocalListener = false;

  bool _handlingAuth = false;
  bool _retryAfterBusy = false;
  bool _receiptDownloadFailed = false;
  Set<String> _failedReceiptUploads = {};
  int _localChangeVersion = 0;
  Future<void> _pendingWrite = Future<void>.value();
  Map<String, String> _cloudReceiptPaths = {};

  Timer? _uploadTimer;

  StreamSubscription<SyncMeta?>? _remoteSubscription;

  SyncStatus get status => _status;

  DateTime? get lastSyncAt => _lastSyncAt;

  String? get message => _message;

  bool get isSyncing => _status == SyncStatus.syncing;

  bool get isAuthenticated => _activeUid != null;

  Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;

    final preferences = await SharedPreferences.getInstance();

    _deviceId = preferences.getString(_deviceIdKey);

    if (_deviceId == null) {
      _deviceId = 'device-${DateTime.now().microsecondsSinceEpoch}';

      await preferences.setString(_deviceIdKey, _deviceId!);
    }

    authController.addListener(_onAuthChanged);

    financeController.addListener(_onLocalDataChanged);

    budgetController.addListener(_onLocalDataChanged);

    goalController.addListener(_onLocalDataChanged);

    debtController.addListener(_onLocalDataChanged);

    await _handleAuthChanged();
  }

  void _onAuthChanged() {
    unawaited(_handleAuthChanged());
  }

  Future<void> _handleAuthChanged() async {
    if (_handlingAuth) {
      return;
    }

    _handlingAuth = true;

    try {
      final uid = authController.user?.uid;

      if (uid == null) {
        _uploadTimer?.cancel();

        await _remoteSubscription?.cancel();

        _remoteSubscription = null;

        _activeUid = null;
        _cloudReceiptPaths = {};

        _setStatus(SyncStatus.idle, message: null);

        return;
      }

      if (uid == _activeUid) {
        return;
      }

      await _openUserSession(uid);
    } finally {
      _handlingAuth = false;
    }
  }

  Future<void> _openUserSession(String uid) async {
    if (_busy) {
      return;
    }

    _busy = true;
    _failedReceiptUploads = {};

    _setStatus(SyncStatus.syncing, message: 'Подготавливаем данные...');

    await _remoteSubscription?.cancel();

    _remoteSubscription = null;

    final preferences = await SharedPreferences.getInstance();

    final claimedUid = preferences.getString(_legacyClaimKey);

    final canClaimLegacy =
        claimedUid == null && financeRepository.isLegacyScope;

    final legacySnapshot = canClaimLegacy ? _currentData() : null;

    try {
      await financeRepository.switchScope(uid);

      await budgetRepository.switchScope(uid);

      await goalRepository.switchScope(uid);

      await debtRepository.switchScope(uid);

      _activeUid = uid;

      final localExists =
          financeRepository.hasStoredData ||
          budgetRepository.hasStoredData ||
          goalRepository.hasStoredData ||
          debtRepository.hasStoredData;

      final cloud = await cloudRepository.download(uid);
      _cloudReceiptPaths = _receiptPaths(cloud?.transactions ?? const []);
      final pending = preferences.getBool('$_pendingKeyPrefix$uid') ?? false;

      if (pending && localExists) {
        await _ensureEmptySlots();
        await _loadControllers();
        await _uploadCurrentInternal(uid: uid);
      } else if (cloud != null) {
        await _applyData(cloud);

        _lastSyncAt = DateTime.now();

        _setStatus(
          SyncStatus.synced,
          message:
              _receiptDownloadFailed
                  ? 'Данные загружены. Часть чеков пока недоступна.'
                  : 'Данные загружены из облака',
        );
      } else if (localExists) {
        await _ensureEmptySlots();

        await _loadControllers();

        await _uploadCurrentInternal(uid: uid);
      } else if (legacySnapshot != null) {
        await _applyData(legacySnapshot);

        await preferences.setString(_legacyClaimKey, uid);

        await _uploadCurrentInternal(uid: uid);
      } else {
        await _applyData(const SyncData.empty());

        await _uploadCurrentInternal(uid: uid);
      }

      await _cleanupFromServer(uid);
      if (_needsReceiptUpload()) {
        _setPending(uid, true);
        if (_failedReceiptUploads.isEmpty) _scheduleUpload();
      }

      _listenRemoteChanges(uid);
    } catch (error) {
      try {
        final localExists =
            financeRepository.hasStoredData ||
            budgetRepository.hasStoredData ||
            goalRepository.hasStoredData ||
            debtRepository.hasStoredData;

        if (localExists) {
          await _ensureEmptySlots();

          await _loadControllers();
        } else if (legacySnapshot != null) {
          await _applyData(legacySnapshot);

          await preferences.setString(_legacyClaimKey, uid);
        } else {
          await _applyData(const SyncData.empty());
        }
      } catch (_) {
        // Не даём вторичной ошибке скрыть
        // основной статус offline.
      }

      _setStatus(
        SyncStatus.offline,
        message:
            'Облако временно недоступно. '
            'Данные сохранены локально.',
      );

      _listenRemoteChanges(uid);

      debugPrint('FinTracker sync session error: $error');
    } finally {
      _busy = false;
      if (_retryAfterBusy) {
        _retryAfterBusy = false;
        _scheduleUpload();
      }
    }
  }

  Future<void> _ensureEmptySlots() async {
    if (!financeRepository.hasStoredData) {
      await financeRepository.save(transactions: const [], accounts: const []);
    }

    if (!budgetRepository.hasStoredData) {
      await budgetRepository.save(const []);
    }

    if (!goalRepository.hasStoredData) {
      await goalRepository.save(const []);
    }

    if (!debtRepository.hasStoredData) {
      await debtRepository.save(const []);
    }
  }

  void _listenRemoteChanges(String uid) {
    _remoteSubscription = cloudRepository
        .watchMeta(uid)
        .listen(
          (meta) {
            if (meta == null ||
                meta.updatedBy == _deviceId ||
                uid != _activeUid ||
                _busy) {
              return;
            }

            unawaited(_pullRemote(uid));
          },
          onError: (error) {
            if (_status != SyncStatus.syncing) {
              _setStatus(
                SyncStatus.offline,
                message:
                    'Нет соединения с облаком. '
                    'Локальные данные доступны.',
              );
            }

            debugPrint('FinTracker sync listener error: $error');
          },
        );
  }

  void _onLocalDataChanged() {
    if (_suspendLocalListener || _activeUid == null) {
      return;
    }

    _setPending(_activeUid!, true);
    _localChangeVersion++;
    if (_busy) {
      _retryAfterBusy = true;
      return;
    }

    _scheduleUpload();
  }

  void _scheduleUpload() {
    _uploadTimer?.cancel();

    _uploadTimer = Timer(const Duration(milliseconds: 1200), () {
      unawaited(syncNow());
    });
  }

  Future<void> syncNow() async {
    final uid = _activeUid;

    if (uid == null || _busy) {
      return;
    }

    _setPending(uid, true);
    await _pendingWrite;
    if (uid != _activeUid || _busy) return;

    _uploadTimer?.cancel();

    _busy = true;

    _setStatus(SyncStatus.syncing, message: 'Синхронизация...');

    try {
      await _uploadCurrentInternal(uid: uid);
    } catch (error) {
      _setStatus(
        SyncStatus.offline,
        message:
            'Не удалось отправить данные. '
            'Они сохранены локально.',
      );

      debugPrint('FinTracker manual sync error: $error');
    } finally {
      _busy = false;
      if (_retryAfterBusy) {
        _retryAfterBusy = false;
        _scheduleUpload();
      }
    }
  }

  Future<void> refreshFromCloud() async {
    final uid = _activeUid;

    if (uid == null || _busy) {
      return;
    }

    await _pullRemote(uid);
  }

  Future<void> _pullRemote(String uid) async {
    if (_busy || uid != _activeUid) {
      return;
    }

    await _pendingWrite;
    final preferences = await SharedPreferences.getInstance();
    if (uid != _activeUid || _busy) return;
    if (preferences.getBool('$_pendingKeyPrefix$uid') ?? false) {
      await syncNow();
      return;
    }

    _busy = true;

    _setStatus(SyncStatus.syncing, message: 'Получаем изменения...');

    try {
      final cloud = await cloudRepository.download(uid);

      if (cloud != null) {
        _cloudReceiptPaths = _receiptPaths(cloud.transactions);
        await _applyData(cloud);
      }

      await _cleanupFromServer(uid);
      if (_needsReceiptUpload()) {
        _setPending(uid, true);
        _scheduleUpload();
      }

      _lastSyncAt = DateTime.now();

      _setStatus(
        SyncStatus.synced,
        message:
            _receiptDownloadFailed
                ? 'Данные актуальны. Часть чеков пока недоступна.'
                : 'Данные актуальны',
      );
    } catch (error) {
      _setStatus(
        SyncStatus.offline,
        message:
            'Не удалось получить облачные данные. '
            'Используются локальные.',
      );

      debugPrint('FinTracker pull sync error: $error');
    } finally {
      _busy = false;
      if (_retryAfterBusy) {
        _retryAfterBusy = false;
        _scheduleUpload();
      }
    }
  }

  Future<void> _uploadCurrentInternal({required String uid}) async {
    final deviceId = _deviceId;

    if (deviceId == null || uid != _activeUid) {
      return;
    }

    await _pendingWrite;
    _failedReceiptUploads = {};
    _suspendLocalListener = true;
    try {
      for (final transaction in financeController.transactions) {
        if (transaction.receiptPath == null ||
            transaction.receiptStoragePath != null ||
            !await _receiptImageService.existsLocally(
              transaction.receiptPath,
            )) {
          continue;
        }

        String path;
        try {
          path = await receiptStorageRepository.upload(
            uid: uid,
            transactionId: transaction.id,
            localPath: transaction.receiptPath!,
          );
        } catch (error) {
          _failedReceiptUploads.add(transaction.id);
          debugPrint('FinTracker receipt upload error: $error');
          continue;
        }
        await _enqueueDeletes(uid, {path});
        if (uid != _activeUid) {
          return;
        }
        final attached = await financeController
            .setTransactionReceiptStoragePath(
              transactionId: transaction.id,
              expectedLocalPath: transaction.receiptPath!,
              storagePath: path,
            );
        if (!attached) {
          await _enqueueDeletes(uid, {path});
        }
      }
    } finally {
      _suspendLocalListener = false;
    }

    final data = _dataForUpload(_currentData());
    final newPaths = _receiptPaths(data.transactions);
    final obsoletePaths = _cloudReceiptPaths.values.toSet().difference(
      newPaths.values.toSet(),
    );
    await _enqueueDeletes(uid, obsoletePaths);

    if (uid != _activeUid) return;

    await cloudRepository.upload(uid: uid, data: data, deviceId: deviceId);

    _cloudReceiptPaths = newPaths;
    final cleaned = await _cleanupPendingDeletes(uid, newPaths.values.toSet());
    if (!_retryAfterBusy && _failedReceiptUploads.isEmpty) {
      _setPending(uid, false);
      await _pendingWrite;
    }

    _lastSyncAt = DateTime.now();

    if (_failedReceiptUploads.isNotEmpty) {
      _setStatus(
        SyncStatus.error,
        message:
            'Операции сохранены в облаке, но чеки пока не загружены. '
            'Локальные файлы сохранены. Повторите синхронизацию позже.',
      );
    } else {
      _setStatus(
        SyncStatus.synced,
        message:
            cleaned
                ? 'Все данные синхронизированы'
                : 'Данные синхронизированы. Удаление старых чеков повторится позже.',
      );
    }
  }

  SyncData _dataForUpload(SyncData data) {
    if (_failedReceiptUploads.isEmpty) return data;

    return SyncData(
      accounts: data.accounts,
      transactions: [
        for (final transaction in data.transactions)
          if (_failedReceiptUploads.contains(transaction.id) &&
              _cloudReceiptPaths[transaction.id] != null)
            transaction.copyWith(
              receiptStoragePath: _cloudReceiptPaths[transaction.id],
            )
          else
            transaction,
      ],
      budgets: data.budgets,
      goals: data.goals,
      debts: data.debts,
    );
  }

  Map<String, String> _receiptPaths(List<FinanceTransaction> transactions) {
    return {
      for (final transaction in transactions)
        if (transaction.receiptStoragePath != null)
          transaction.id: transaction.receiptStoragePath!,
    };
  }

  bool _needsReceiptUpload() {
    return financeController.transactions.any(
      (transaction) =>
          transaction.receiptPath != null &&
          transaction.receiptStoragePath == null,
    );
  }

  void _setPending(String uid, bool value) {
    _pendingWrite = _pendingWrite.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('$_pendingKeyPrefix$uid', value);
    });
  }

  Future<void> _enqueueDeletes(String uid, Set<String> paths) async {
    if (paths.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final key = '$_deleteKeyPrefix$uid';
    final queued = preferences.getStringList(key) ?? const <String>[];
    await preferences.setStringList(key, {...queued, ...paths}.toList());
  }

  Future<bool> _cleanupPendingDeletes(String uid, Set<String> livePaths) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_deleteKeyPrefix$uid';
    final queued = preferences.getStringList(key) ?? const <String>[];
    final remaining = <String>[];
    for (final path in queued) {
      if (livePaths.contains(path)) {
        continue;
      }
      try {
        await receiptStorageRepository.delete(uid: uid, storagePath: path);
      } catch (error) {
        remaining.add(path);
        debugPrint('FinTracker receipt cleanup error: $error');
      }
    }
    await preferences.setStringList(key, remaining);
    return remaining.isEmpty;
  }

  Future<void> _cleanupFromServer(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    if ((preferences.getStringList('$_deleteKeyPrefix$uid') ?? const [])
        .isEmpty) {
      return;
    }
    try {
      final livePaths = await cloudRepository.receiptPathsFromServer(uid);
      await _cleanupPendingDeletes(uid, livePaths);
    } catch (error) {
      debugPrint('FinTracker deferred receipt cleanup: $error');
    }
  }

  Future<bool> ensureReceiptCached(String transactionId) async {
    final uid = _activeUid;
    final transaction = financeController.transactionById(transactionId);
    final storagePath = transaction?.receiptStoragePath;
    if (uid == null || transaction == null || storagePath == null) {
      return false;
    }
    if (await _receiptImageService.existsLocally(transaction.receiptPath)) {
      return true;
    }

    try {
      final localPath = await receiptStorageRepository.download(
        uid: uid,
        transactionId: transactionId,
        storagePath: storagePath,
      );
      if (uid != _activeUid) return false;
      _suspendLocalListener = true;
      try {
        return await financeController.setTransactionReceiptCache(
          transactionId: transactionId,
          storagePath: storagePath,
          localPath: localPath,
        );
      } finally {
        _suspendLocalListener = false;
      }
    } catch (error) {
      debugPrint('FinTracker receipt download error: $error');
      return false;
    }
  }

  SyncData _currentData() {
    return SyncData(
      accounts: List.of(financeController.accounts),
      transactions: List.of(financeController.transactions),
      budgets: List.of(budgetController.budgets),
      goals: List.of(goalController.goals),
      debts: List.of(debtController.debts),
    );
  }

  Future<void> _applyData(SyncData data) async {
    try {
      final initialChangeVersion = _localChangeVersion;
      _receiptDownloadFailed = false;
      final uid = _activeUid;
      final saved = await financeRepository.load();
      final localById = {
        for (final transaction in saved?.transactions ?? <FinanceTransaction>[])
          transaction.id: transaction,
      };
      final transactions = <FinanceTransaction>[];
      for (final transaction in data.transactions) {
        final storagePath = transaction.receiptStoragePath;
        String? localPath;
        if (storagePath != null && uid != null) {
          final existing = localById[transaction.id];
          if (existing?.receiptStoragePath == storagePath &&
              await _receiptImageService.existsLocally(existing?.receiptPath)) {
            localPath = existing!.receiptPath;
          } else {
            try {
              localPath = await receiptStorageRepository.download(
                uid: uid,
                transactionId: transaction.id,
                storagePath: storagePath,
              );
            } catch (error) {
              _receiptDownloadFailed = true;
              debugPrint('FinTracker receipt download error: $error');
            }
          }
        } else if (await _receiptImageService.existsLocally(
          transaction.receiptPath,
        )) {
          localPath = transaction.receiptPath;
        } else if (transaction.receiptPath != null &&
            await _receiptImageService.existsLocally(
              localById[transaction.id]?.receiptPath,
            )) {
          localPath = localById[transaction.id]!.receiptPath;
        }
        transactions.add(
          transaction.copyWith(
            receiptPath: localPath,
            clearReceiptPath: localPath == null,
          ),
        );
      }

      if (initialChangeVersion != _localChangeVersion) {
        throw StateError('Local data changed during cloud download.');
      }

      _suspendLocalListener = true;
      await financeRepository.save(
        transactions: transactions,
        accounts: data.accounts,
      );

      final currentPaths = {
        for (final transaction in transactions)
          if (transaction.receiptPath != null)
            transaction.id: transaction.receiptPath!,
      };
      for (final old in localById.values) {
        if (old.receiptPath != null &&
            currentPaths[old.id] != old.receiptPath) {
          try {
            await _receiptImageService.delete(old.receiptPath);
          } catch (error) {
            debugPrint('FinTracker local receipt cleanup error: $error');
          }
        }
      }

      await budgetRepository.save(data.budgets);

      await goalRepository.save(data.goals);

      await debtRepository.save(data.debts);

      await _loadControllers();
    } finally {
      _suspendLocalListener = false;
    }
  }

  Future<void> _loadControllers() async {
    _suspendLocalListener = true;

    try {
      await financeController.load();

      await budgetController.load();

      await goalController.load();

      await debtController.load();
    } finally {
      _suspendLocalListener = false;
    }
  }

  void _setStatus(SyncStatus status, {String? message}) {
    _status = status;
    _message = message;

    notifyListeners();
  }

  @override
  void dispose() {
    _uploadTimer?.cancel();

    _remoteSubscription?.cancel();

    authController.removeListener(_onAuthChanged);

    financeController.removeListener(_onLocalDataChanged);

    budgetController.removeListener(_onLocalDataChanged);

    goalController.removeListener(_onLocalDataChanged);

    debtController.removeListener(_onLocalDataChanged);

    super.dispose();
  }
}
