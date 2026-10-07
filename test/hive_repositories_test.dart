import 'dart:io';

import 'package:fin_tracker/data/repositories/hive_budget_repository.dart';
import 'package:fin_tracker/data/repositories/hive_debt_repository.dart';
import 'package:fin_tracker/data/repositories/hive_finance_repository.dart';
import 'package:fin_tracker/data/repositories/hive_goal_repository.dart';
import 'package:fin_tracker/domain/entities/account.dart';
import 'package:fin_tracker/domain/entities/budget.dart';
import 'package:fin_tracker/domain/entities/debt.dart';
import 'package:fin_tracker/domain/entities/finance_transaction.dart';
import 'package:fin_tracker/domain/entities/savings_goal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fintracker-hive-tests-');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'finance round trip preserves account and transaction metadata',
    () async {
      final repository = HiveFinanceRepository();
      await repository.init(scope: 'user-1');
      expect(await repository.load(), isNull);
      expect(repository.hasStoredData, isFalse);
      final date = DateTime(2026, 3, 4, 12);
      await repository.save(
        accounts: const [
          Account(
            id: 'bank',
            name: 'Bank',
            type: AccountType.card,
            balance: 600,
            bankName: 'Example Bank',
            currency: 'USD',
            includeInTotal: false,
          ),
        ],
        transactions: [
          FinanceTransaction(
            id: 'tx',
            type: FinanceTransactionType.expense,
            amount: 50,
            accountId: 'bank',
            categoryId: 'food',
            title: 'Lunch',
            person: 'Alex',
            description: 'Cafe',
            date: date,
            receiptPath: '/local/receipt.jpg',
            receiptStoragePath: 'users/u/receipts/tx/receipt.jpg',
            latitude: 44.8,
            longitude: 65.5,
          ),
        ],
      );

      final saved = (await repository.load())!;
      expect(repository.hasStoredData, isTrue);
      expect(saved.accounts.single.bankName, 'Example Bank');
      expect(saved.accounts.single.currency, 'USD');
      expect(saved.accounts.single.includeInTotal, isFalse);
      final receipt = saved.transactions.single;
      expect(receipt.date, date);
      expect(receipt.person, 'Alex');
      expect(receipt.receiptPath, '/local/receipt.jpg');
      expect(receipt.receiptStoragePath, 'users/u/receipts/tx/receipt.jpg');
      expect(receipt.latitude, 44.8);
      expect(receipt.longitude, 65.5);

      await repository.switchScope('user-2');
      expect(await repository.load(), isNull);
      await repository.switchScope('user-1');
      expect((await repository.load())!.transactions.single.id, 'tx');
    },
  );

  test(
    'old finance maps load with defaults and skip corrupt entries',
    () async {
      final box = await Hive.openBox<dynamic>('fintracker_finance_legacy-test');
      await box.put('accounts_v2', [
        {'id': 'cash', 'name': 'Cash', 'type': 'cash', 'balance': 100},
        {'bad': 'account'},
      ]);
      await box.put('transactions', [
        {
          'id': 'old',
          'type': 'expense',
          'amount': 12,
          'accountId': 'cash',
          'title': 'Old',
          'date': '2025-01-01T00:00:00.000',
          'receiptPath': '/old/path.jpg',
        },
        {'bad': 'transaction'},
      ]);
      final repository = HiveFinanceRepository();
      await repository.init(scope: 'legacy-test');
      final loaded = (await repository.load())!;
      expect(loaded.accounts, hasLength(1));
      expect(loaded.accounts.single.currency, 'KZT');
      expect(loaded.accounts.single.includeInTotal, isTrue);
      expect(loaded.transactions, hasLength(1));
      expect(loaded.transactions.single.receiptPath, '/old/path.jpg');
      expect(loaded.transactions.single.receiptStoragePath, isNull);
      expect(loaded.transactions.single.latitude, isNull);
    },
  );

  test('budget, goal and debt repositories round trip payments', () async {
    final created = DateTime(2026, 1, 2);
    final budgetRepository = HiveBudgetRepository();
    final goalRepository = HiveGoalRepository();
    final debtRepository = HiveDebtRepository();
    await budgetRepository.init(scope: 'user-1');
    await goalRepository.init(scope: 'user-1');
    await debtRepository.init(scope: 'user-1');
    expect(await budgetRepository.load(), isEmpty);
    expect(await goalRepository.load(), isEmpty);
    expect(await debtRepository.load(), isEmpty);

    await budgetRepository.save([
      Budget(
        id: 'b',
        categoryId: 'food',
        monthlyLimit: 250,
        enabled: false,
        createdAt: created,
      ),
    ]);
    await goalRepository.save([
      SavingsGoal(
        id: 'g',
        name: 'Trip',
        targetAmount: 1000,
        currentAmount: 300,
        deadline: DateTime(2027, 1),
        createdAt: created,
        linkedAccountId: 'bank',
      ),
    ]);
    await debtRepository.save([
      Debt(
        id: 'd',
        type: DebtType.owedToMe,
        person: 'Alex',
        originalAmount: 500,
        remainingAmount: 200,
        createdAt: created,
        note: 'Loan',
        payments: [
          DebtPayment(
            id: 'p',
            amount: 300,
            date: created,
            accountId: 'bank',
            transactionId: 'tx',
          ),
        ],
      ),
    ]);

    expect((await budgetRepository.load()).single.enabled, isFalse);
    expect((await goalRepository.load()).single.linkedAccountId, 'bank');
    final debt = (await debtRepository.load()).single;
    expect(debt.remainingAmount, 200);
    expect(debt.payments.single.transactionId, 'tx');
    expect(debt.payments.single.accountId, 'bank');
  });
}
