import '../entities/debt.dart';

abstract class DebtRepository {
  Future<List<Debt>> load();

  Future<void> save(List<Debt> debts);
}
