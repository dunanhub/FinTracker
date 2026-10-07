import 'package:fin_tracker/domain/entities/account.dart';
import 'package:fin_tracker/domain/entities/finance_transaction.dart';
import 'package:fin_tracker/presentation/controllers/finance_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_repositories.dart';

const cash = Account(
  id: 'cash',
  name: 'Cash',
  type: AccountType.cash,
  balance: 1000,
);
const bank = Account(
  id: 'bank',
  name: 'Bank',
  type: AccountType.card,
  balance: 500,
);

FinanceTransaction transaction(
  String id,
  FinanceTransactionType type,
  double amount,
  DateTime date, {
  String accountId = 'cash',
  String? categoryId,
}) => FinanceTransaction(
  id: id,
  type: type,
  amount: amount,
  accountId: accountId,
  categoryId: categoryId,
  title: id,
  date: date,
);

void main() {
  test(
    'expense, income and transfer update both balances and persist',
    () async {
      final repository = FakeFinanceRepository(accounts: [cash, bank]);
      final finance = FinanceController(repository: repository);
      await finance.load();

      await finance.addTransaction(
        type: FinanceTransactionType.expense,
        amount: 120,
        accountId: 'cash',
        title: 'Lunch',
        date: DateTime(2026, 1, 1),
      );
      expect(finance.accountBalance('cash'), 880);

      await finance.addTransaction(
        type: FinanceTransactionType.income,
        amount: 300,
        accountId: 'bank',
        title: 'Salary',
        date: DateTime(2026, 1, 2),
      );
      expect(finance.accountBalance('bank'), 800);

      await finance.addTransaction(
        type: FinanceTransactionType.transfer,
        amount: 200,
        accountId: 'cash',
        destinationAccountId: 'bank',
        title: 'Move',
        date: DateTime(2026, 1, 3),
      );
      expect(finance.accountBalance('cash'), 680);
      expect(finance.accountBalance('bank'), 1000);
      expect(repository.accounts.last.balance, 1000);
      expect(repository.transactions, hasLength(3));
    },
  );

  test('editing reverses old effect and deleting restores balance', () async {
    final finance = FinanceController(
      repository: FakeFinanceRepository(accounts: [cash, bank]),
    );
    await finance.load();
    final id = await finance.addTransaction(
      type: FinanceTransactionType.transfer,
      amount: 200,
      accountId: 'cash',
      destinationAccountId: 'bank',
      title: 'Move',
      date: DateTime(2026, 1, 1),
    );
    expect(finance.accountBalance('cash'), 800);
    expect(finance.accountBalance('bank'), 700);

    expect(
      await finance.updateTransaction(
        id: id,
        type: FinanceTransactionType.expense,
        amount: 50,
        accountId: 'bank',
        title: 'Fee',
        date: DateTime(2026, 1, 2),
      ),
      isTrue,
    );
    expect(finance.accountBalance('cash'), 1000);
    expect(finance.accountBalance('bank'), 450);
    expect(await finance.deleteTransaction(id), isTrue);
    expect(finance.accountBalance('bank'), 500);
    expect(await finance.deleteTransaction(id), isFalse);
  });

  test('transactions sort by date and categories resolve correctly', () async {
    final finance = FinanceController(
      repository: FakeFinanceRepository(
        accounts: [cash],
        transactions: [
          transaction('old', FinanceTransactionType.expense, 1, DateTime(2025)),
          transaction('new', FinanceTransactionType.income, 2, DateTime(2026)),
        ],
      ),
    );
    await finance.load();
    expect(finance.transactions.map((item) => item.id), ['new', 'old']);
    expect(finance.categoryName('food'), 'Еда');
    expect(finance.categoryName('salary'), 'Зарплата');
    expect(
      finance.categoryName(FinanceController.debtPaymentCategoryId),
      'Долг',
    );
    expect(finance.categoryName(null), 'Перевод');
  });

  test(
    'monthly totals and analytics exclude debt payments and transfers',
    () async {
      final now = DateTime.now();
      final current = DateTime(now.year, now.month, 1);
      final previous = DateTime(now.year, now.month - 1, 1);
      final finance = FinanceController(
        repository: FakeFinanceRepository(
          accounts: [cash, bank],
          transactions: [
            transaction(
              'salary',
              FinanceTransactionType.income,
              500,
              current,
              categoryId: 'salary',
            ),
            transaction(
              'food',
              FinanceTransactionType.expense,
              120,
              current,
              categoryId: 'food',
            ),
            transaction(
              'rent',
              FinanceTransactionType.expense,
              80,
              current,
              categoryId: 'housing',
            ),
            transaction(
              'debt',
              FinanceTransactionType.expense,
              70,
              current,
              categoryId: FinanceController.debtPaymentCategoryId,
            ),
            transaction(
              'old',
              FinanceTransactionType.expense,
              100,
              previous,
              categoryId: 'food',
            ),
          ],
        ),
      );
      await finance.load();
      await finance.addTransaction(
        type: FinanceTransactionType.transfer,
        amount: 50,
        accountId: 'cash',
        destinationAccountId: 'bank',
        title: 'Transfer',
        date: current,
      );

      expect(finance.monthlyIncome, 500);
      expect(finance.monthlyExpense, 200);
      expect(finance.monthlySavings, 300);
      final snapshot = finance.analyticsSnapshot(
        AnalyticsPeriod.month,
        at: now,
      );
      expect(snapshot.income, 500);
      expect(snapshot.expense, 200);
      expect(snapshot.savings, 300);
      expect(snapshot.savingsRate, 60);
      expect(snapshot.previousExpense, 100);
      expect(snapshot.expenseChangePercent, 100);
      expect(snapshot.categories.map((item) => item.id), ['food', 'housing']);
      expect(snapshot.chartValues.first, 200);
    },
  );

  test(
    'location and receipt metadata survive ordinary edit and cache update',
    () async {
      final repository = FakeFinanceRepository(accounts: [cash]);
      final finance = FinanceController(repository: repository);
      await finance.load();
      final id = await finance.addTransaction(
        type: FinanceTransactionType.expense,
        amount: 20,
        accountId: 'cash',
        title: 'Coffee',
        date: DateTime(2026, 1, 1),
        receiptPath: '/local/receipt.jpg',
        latitude: 44.8,
        longitude: 65.5,
      );
      expect(
        await finance.setTransactionReceiptStoragePath(
          transactionId: id,
          expectedLocalPath: '/local/receipt.jpg',
          storagePath: 'users/u/receipts/$id/receipt.jpg',
        ),
        isTrue,
      );
      expect(
        await finance.updateTransaction(
          id: id,
          type: FinanceTransactionType.expense,
          amount: 25,
          accountId: 'cash',
          title: 'Coffee again',
          date: DateTime(2026, 1, 2),
        ),
        isTrue,
      );
      final edited = finance.transactionById(id)!;
      expect(edited.receiptPath, '/local/receipt.jpg');
      expect(edited.receiptStoragePath, 'users/u/receipts/$id/receipt.jpg');
      expect(edited.latitude, 44.8);
      expect(edited.longitude, 65.5);
      expect(finance.accountBalance('cash'), 975);

      expect(
        await finance.setTransactionReceiptCache(
          transactionId: id,
          storagePath: 'users/u/receipts/$id/receipt.jpg',
          localPath: '/new/cache.jpg',
        ),
        isTrue,
      );
      expect(repository.transactions.single.receiptPath, '/new/cache.jpg');
      expect(
        await finance.setTransactionLocation(
          transactionId: id,
          latitude: 45,
          longitude: 66,
        ),
        isTrue,
      );
      expect(repository.transactions.single.longitude, 66);
    },
  );
}
