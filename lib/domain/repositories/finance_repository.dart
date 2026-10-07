import '../entities/account.dart';
import '../entities/finance_transaction.dart';

class FinanceStorageData {
  final List<FinanceTransaction> transactions;
  final List<Account> accounts;

  const FinanceStorageData({
    required this.transactions,
    required this.accounts,
  });
}

abstract class FinanceRepository {
  Future<FinanceStorageData?> load();

  Future<void> save({
    required List<FinanceTransaction> transactions,
    required List<Account> accounts,
  });
}
