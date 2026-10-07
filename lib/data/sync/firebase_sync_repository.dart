import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/entities/savings_goal.dart';

class SyncData {
  final List<Account> accounts;

  final List<FinanceTransaction> transactions;

  final List<Budget> budgets;

  final List<SavingsGoal> goals;

  final List<Debt> debts;

  const SyncData({
    required this.accounts,
    required this.transactions,
    required this.budgets,
    required this.goals,
    required this.debts,
  });

  bool get isEmpty =>
      accounts.isEmpty &&
      transactions.isEmpty &&
      budgets.isEmpty &&
      goals.isEmpty &&
      debts.isEmpty;

  const SyncData.empty()
    : accounts = const [],
      transactions = const [],
      budgets = const [],
      goals = const [],
      debts = const [];
}

class SyncMeta {
  final DateTime? updatedAt;
  final String? updatedBy;

  const SyncMeta({this.updatedAt, this.updatedBy});
}

class FirebaseSyncRepository {
  final FirebaseFirestore _firestore;

  FirebaseSyncRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _user(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _meta(String uid) {
    return _user(uid).collection('_sync').doc('meta');
  }

  Stream<SyncMeta?> watchMeta(String uid) {
    return _meta(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();

      if (data == null) {
        return null;
      }

      final timestamp = data['updatedAt'];

      return SyncMeta(
        updatedAt: timestamp is Timestamp ? timestamp.toDate() : null,
        updatedBy: data['updatedBy'] as String?,
      );
    });
  }

  Future<SyncData?> download(String uid) async {
    final user = _user(uid);

    final accountsSnapshot = await user.collection('accounts').get();

    final transactionsSnapshot = await user.collection('transactions').get();

    final budgetsSnapshot = await user.collection('budgets').get();

    final goalsSnapshot = await user.collection('goals').get();

    final debtsSnapshot = await user.collection('debts').get();

    final metaSnapshot = await _meta(uid).get();

    final hasCloudState =
        metaSnapshot.exists ||
        accountsSnapshot.docs.isNotEmpty ||
        transactionsSnapshot.docs.isNotEmpty ||
        budgetsSnapshot.docs.isNotEmpty ||
        goalsSnapshot.docs.isNotEmpty ||
        debtsSnapshot.docs.isNotEmpty;

    if (!hasCloudState) {
      return null;
    }

    return SyncData(
      accounts:
          accountsSnapshot.docs
              .map((doc) => _accountFromMap(doc.data()))
              .toList(),
      transactions:
          transactionsSnapshot.docs
              .map((doc) => _transactionFromMap(doc.data()))
              .toList(),
      budgets:
          budgetsSnapshot.docs
              .map((doc) => _budgetFromMap(doc.data()))
              .toList(),
      goals: goalsSnapshot.docs.map((doc) => _goalFromMap(doc.data())).toList(),
      debts: debtsSnapshot.docs.map((doc) => _debtFromMap(doc.data())).toList(),
    );
  }

  Future<Set<String>> receiptPathsFromServer(String uid) async {
    final snapshot = await _user(
      uid,
    ).collection('transactions').get(const GetOptions(source: Source.server));
    return {
      for (final document in snapshot.docs)
        if (document.data()['receiptStoragePath'] is String)
          document.data()['receiptStoragePath'] as String,
    };
  }

  Future<void> upload({
    required String uid,
    required SyncData data,
    required String deviceId,
  }) async {
    final user = _user(uid);

    await _replaceCollection(
      collection: user.collection('accounts'),
      documents: {
        for (final account in data.accounts) account.id: _accountToMap(account),
      },
    );

    await _replaceCollection(
      collection: user.collection('transactions'),
      documents: {
        for (final transaction in data.transactions)
          transaction.id: _transactionToMap(transaction),
      },
    );

    await _replaceCollection(
      collection: user.collection('budgets'),
      documents: {
        for (final budget in data.budgets) budget.id: _budgetToMap(budget),
      },
    );

    await _replaceCollection(
      collection: user.collection('goals'),
      documents: {for (final goal in data.goals) goal.id: _goalToMap(goal)},
    );

    await _replaceCollection(
      collection: user.collection('debts'),
      documents: {for (final debt in data.debts) debt.id: _debtToMap(debt)},
    );

    await _meta(uid).set({
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': deviceId,
    }, SetOptions(merge: true));
  }

  Future<void> _replaceCollection({
    required CollectionReference<Map<String, dynamic>> collection,
    required Map<String, Map<String, dynamic>> documents,
  }) async {
    final old = await collection.get();

    var batch = _firestore.batch();

    var operations = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (operations == 0) {
        return;
      }

      if (!force && operations < 400) {
        return;
      }

      await batch.commit();

      batch = _firestore.batch();

      operations = 0;
    }

    for (final document in old.docs) {
      if (documents.containsKey(document.id)) {
        continue;
      }

      batch.delete(document.reference);

      operations++;

      await commitIfNeeded();
    }

    for (final entry in documents.entries) {
      batch.set(collection.doc(entry.key), entry.value);

      operations++;

      await commitIfNeeded();
    }

    await commitIfNeeded(force: true);
  }

  Map<String, dynamic> _accountToMap(Account account) {
    return {
      'id': account.id,
      'name': account.name,
      'type': account.type.name,
      'balance': account.balance,
      'currency': account.currency,
      'bankName': account.bankName,
      'includeInTotal': account.includeInTotal,
    };
  }

  Account _accountFromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      type: AccountType.values.byName(map['type'] as String),
      balance: (map['balance'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'KZT',
      bankName: map['bankName'] as String?,
      includeInTotal: map['includeInTotal'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _transactionToMap(FinanceTransaction transaction) {
    return {
      'id': transaction.id,
      'type': transaction.type.name,
      'amount': transaction.amount,
      'accountId': transaction.accountId,
      'destinationAccountId': transaction.destinationAccountId,
      'categoryId': transaction.categoryId,
      'title': transaction.title,
      'person': transaction.person,
      'description': transaction.description,
      'date': transaction.date.toIso8601String(),
      'receiptStoragePath': transaction.receiptStoragePath,
      'latitude': transaction.latitude,
      'longitude': transaction.longitude,
    };
  }

  FinanceTransaction _transactionFromMap(Map<String, dynamic> map) {
    return FinanceTransaction(
      id: map['id'] as String,
      type: FinanceTransactionType.values.byName(map['type'] as String),
      amount: (map['amount'] as num).toDouble(),
      accountId: map['accountId'] as String,
      destinationAccountId: map['destinationAccountId'] as String?,
      categoryId: map['categoryId'] as String?,
      title: map['title'] as String,
      person: map['person'] as String?,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      receiptPath: map['receiptPath'] as String?,
      receiptStoragePath: map['receiptStoragePath'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> _budgetToMap(Budget budget) {
    return {
      'id': budget.id,
      'categoryId': budget.categoryId,
      'monthlyLimit': budget.monthlyLimit,
      'enabled': budget.enabled,
      'createdAt': budget.createdAt.toIso8601String(),
    };
  }

  Budget _budgetFromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      categoryId: map['categoryId'] as String,
      monthlyLimit: (map['monthlyLimit'] as num).toDouble(),
      enabled: map['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> _goalToMap(SavingsGoal goal) {
    return {
      'id': goal.id,
      'name': goal.name,
      'targetAmount': goal.targetAmount,
      'currentAmount': goal.currentAmount,
      'deadline': goal.deadline.toIso8601String(),
      'createdAt': goal.createdAt.toIso8601String(),
      'linkedAccountId': goal.linkedAccountId,
    };
  }

  SavingsGoal _goalFromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'] as String,
      name: map['name'] as String,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num).toDouble(),
      deadline: DateTime.parse(map['deadline'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      linkedAccountId: map['linkedAccountId'] as String?,
    );
  }

  Map<String, dynamic> _debtToMap(Debt debt) {
    return {
      'id': debt.id,
      'type': debt.type.name,
      'person': debt.person,
      'originalAmount': debt.originalAmount,
      'remainingAmount': debt.remainingAmount,
      'deadline': debt.deadline?.toIso8601String(),
      'note': debt.note,
      'createdAt': debt.createdAt.toIso8601String(),
      'payments':
          debt.payments
              .map(
                (payment) => {
                  'id': payment.id,
                  'amount': payment.amount,
                  'date': payment.date.toIso8601String(),
                  'accountId': payment.accountId,
                  'transactionId': payment.transactionId,
                },
              )
              .toList(),
    };
  }

  Debt _debtFromMap(Map<String, dynamic> map) {
    final payments = <DebtPayment>[];

    final rawPayments = map['payments'];

    if (rawPayments is List) {
      for (final raw in rawPayments) {
        if (raw is! Map) {
          continue;
        }

        final item = Map<String, dynamic>.from(raw);

        payments.add(
          DebtPayment(
            id: item['id'] as String,
            amount: (item['amount'] as num).toDouble(),
            date: DateTime.parse(item['date'] as String),
            accountId: item['accountId'] as String?,
            transactionId: item['transactionId'] as String?,
          ),
        );
      }
    }

    return Debt(
      id: map['id'] as String,
      type: DebtType.values.byName(map['type'] as String),
      person: map['person'] as String,
      originalAmount: (map['originalAmount'] as num).toDouble(),
      remainingAmount: (map['remainingAmount'] as num).toDouble(),
      deadline:
          map['deadline'] == null
              ? null
              : DateTime.parse(map['deadline'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      payments: payments,
    );
  }
}
