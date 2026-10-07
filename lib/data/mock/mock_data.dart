import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/entities/financial_goal.dart';

class MockData {
  MockData._();

  static const accounts = [
    Account(
      id: 'kaspi',
      name: 'Kaspi Gold',
      type: AccountType.card,
      balance: 850000,
      bankName: 'Kaspi Bank',
    ),
    Account(
      id: 'halyk',
      name: 'Halyk',
      type: AccountType.card,
      balance: 370000,
      bankName: 'Halyk Bank',
    ),
    Account(
      id: 'deposit',
      name: 'Отбасы депозит',
      type: AccountType.deposit,
      balance: 580000,
      bankName: 'Отбасы Банк',
    ),
    Account(
      id: 'cash',
      name: 'Наличные',
      type: AccountType.cash,
      balance: 75600,
    ),
  ];

  static const categories = [
    FinanceCategory(
      id: 'food',
      name: 'Еда',
      type: CategoryType.expense,
      icon: 'restaurant',
    ),
    FinanceCategory(
      id: 'housing',
      name: 'Жильё',
      type: CategoryType.expense,
      icon: 'home',
    ),
    FinanceCategory(
      id: 'transport',
      name: 'Транспорт',
      type: CategoryType.expense,
      icon: 'directions_car',
    ),
    FinanceCategory(
      id: 'salary',
      name: 'Зарплата',
      type: CategoryType.income,
      icon: 'work',
    ),
  ];

  static final transactions = [
    FinanceTransaction(
      id: '1',
      type: FinanceTransactionType.expense,
      amount: 12500,
      accountId: 'kaspi',
      categoryId: 'food',
      title: 'Ужин',
      person: 'Друзья',
      date: DateTime(2026, 10, 2, 20, 30),
    ),
    FinanceTransaction(
      id: '2',
      type: FinanceTransactionType.income,
      amount: 220000,
      accountId: 'halyk',
      categoryId: 'salary',
      title: 'Зарплата',
      person: 'Работа',
      date: DateTime(2026, 9, 28),
    ),
    FinanceTransaction(
      id: '3',
      type: FinanceTransactionType.expense,
      amount: 130000,
      accountId: 'kaspi',
      categoryId: 'housing',
      title: 'Аренда квартиры',
      date: DateTime(2026, 10, 1),
    ),
  ];

  static final goals = [
    FinancialGoal(
      id: 'apartment',
      name: 'Первоначальный взнос',
      targetAmount: 15000000,
      currentAmount: 2500000,
      targetDate: DateTime(2029, 10, 1),
    ),
  ];

  static final debts = [
    Debt(
      id: '1',
      type: DebtType.owedToMe,
      person: 'Данияр',
      originalAmount: 150000,
      remainingAmount: 100000,
      createdAt: DateTime(2026, 9, 1),
      deadline: DateTime(2026, 10, 15),
    ),
  ];
}
