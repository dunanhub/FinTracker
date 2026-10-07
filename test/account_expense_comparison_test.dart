import 'package:fin_tracker/domain/entities/account.dart';
import 'package:fin_tracker/domain/entities/finance_transaction.dart';
import 'package:fin_tracker/domain/repositories/finance_repository.dart';
import 'package:fin_tracker/presentation/controllers/finance_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _TransactionRepository implements FinanceRepository {
  final List<FinanceTransaction> transactions;

  _TransactionRepository(this.transactions);

  @override
  Future<FinanceStorageData> load() async => FinanceStorageData(
    transactions: transactions,
    accounts: const <Account>[],
  );

  @override
  Future<void> save({
    required List<FinanceTransaction> transactions,
    required List<Account> accounts,
  }) async {}
}

FinanceTransaction _transaction(
  String id,
  String accountId,
  DateTime date,
  double amount, {
  FinanceTransactionType type = FinanceTransactionType.expense,
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
    'comparison uses each account and the same days across year boundary',
    () async {
      final finance = FinanceController(
        repository: _TransactionRepository([
          _transaction('dec-1', 'kaspi', DateTime(2029, 12, 1), 100),
          _transaction('dec-6', 'kaspi', DateTime(2029, 12, 6, 23), 100),
          _transaction('dec-7', 'kaspi', DateTime(2029, 12, 7), 900),
          _transaction('jan-1', 'kaspi', DateTime(2030, 1, 1), 50),
          _transaction('jan-6', 'kaspi', DateTime(2030, 1, 6, 23), 100),
          _transaction('jan-7', 'kaspi', DateTime(2030, 1, 7), 900),
          _transaction('other-account', 'halyk', DateTime(2030, 1, 6), 300),
          _transaction(
            'income',
            'kaspi',
            DateTime(2030, 1, 6),
            500,
            type: FinanceTransactionType.income,
          ),
          _transaction(
            'transfer',
            'kaspi',
            DateTime(2030, 1, 6),
            500,
            type: FinanceTransactionType.transfer,
          ),
          _transaction(
            'debt',
            'kaspi',
            DateTime(2030, 1, 6),
            500,
            categoryId: FinanceController.debtPaymentCategoryId,
          ),
        ]),
      );
      await finance.load();

      final kaspi = finance.accountExpenseComparison(
        'kaspi',
        at: DateTime(2030, 1, 6, 12),
      );
      expect(kaspi.currentExpense, 150);
      expect(kaspi.previousExpense, 200);
      expect(kaspi.percentChange, -25);

      final halyk = finance.accountExpenseComparison(
        'halyk',
        at: DateTime(2030, 1, 6, 12),
      );
      expect(halyk.currentExpense, 300);
      expect(halyk.previousExpense, 0);
      expect(halyk.percentChange, isNull);
    },
  );

  test(
    'comparison includes the last available day of a leap February',
    () async {
      final finance = FinanceController(
        repository: _TransactionRepository([
          _transaction('feb-29', 'cash', DateTime(2032, 2, 29), 120),
          _transaction('mar-31', 'cash', DateTime(2032, 3, 31), 60),
        ]),
      );
      await finance.load();

      final result = finance.accountExpenseComparison(
        'cash',
        at: DateTime(2032, 3, 31),
      );
      expect(result.previousExpense, 120);
      expect(result.currentExpense, 60);
      expect(result.percentChange, -50);
    },
  );

  test(
    'equal spending is neutral and no spending is a full decrease',
    () async {
      final finance = FinanceController(
        repository: _TransactionRepository([
          _transaction('previous', 'cash', DateTime(2030, 5, 2), 100),
          _transaction('current', 'cash', DateTime(2030, 6, 2), 100),
        ]),
      );
      await finance.load();

      expect(
        finance
            .accountExpenseComparison('cash', at: DateTime(2030, 6, 2))
            .percentChange,
        0,
      );
      expect(
        finance
            .accountExpenseComparison('cash', at: DateTime(2030, 7, 2))
            .percentChange,
        -100,
      );
    },
  );
}
