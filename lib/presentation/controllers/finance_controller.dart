import 'package:flutter/foundation.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/repositories/finance_repository.dart';

enum AnalyticsPeriod { week, month, year }

enum AccountDeleteResult { success, hasTransactions, notFound }

class ExpenseChartSeries {
  final List<DateTime> dates;
  final List<double> values;

  const ExpenseChartSeries({required this.dates, required this.values});
}

class AccountExpenseComparison {
  final double currentExpense;
  final double previousExpense;
  final double? percentChange;

  const AccountExpenseComparison({
    required this.currentExpense,
    required this.previousExpense,
    required this.percentChange,
  });
}

class FinanceCategoryTotal {
  final String id;
  final String name;
  final double amount;

  const FinanceCategoryTotal({
    required this.id,
    required this.name,
    required this.amount,
  });
}

class AnalyticsSnapshot {
  final AnalyticsPeriod period;

  final double income;
  final double expense;
  final double savings;
  final double savingsRate;

  final double previousExpense;
  final double expenseChangePercent;
  final bool hasPreviousData;

  final List<double> chartValues;
  final List<DateTime> chartDates;
  final List<String> chartLabels;

  final List<FinanceCategoryTotal> categories;

  const AnalyticsSnapshot({
    required this.period,
    required this.income,
    required this.expense,
    required this.savings,
    required this.savingsRate,
    required this.previousExpense,
    required this.expenseChangePercent,
    required this.hasPreviousData,
    required this.chartValues,
    required this.chartDates,
    required this.chartLabels,
    required this.categories,
  });
}

class FinanceController extends ChangeNotifier {
  final FinanceRepository? repository;

  FinanceController({this.repository});

  // Специальная категория для выплат долгов.
  //
  // Такие операции меняют баланс счёта,
  // но НЕ должны попадать в обычные
  // доходы/расходы аналитики.
  static const String debtPaymentCategoryId = '__debt_payment__';

  static const Map<String, String> expenseCategories = {
    'food': 'Еда',
    'housing': 'Жильё',
    'transport': 'Транспорт',
    'subscriptions': 'Подписки',
    'shopping': 'Покупки',
    'health': 'Здоровье',
    'entertainment': 'Развлечения',
    'other-expense': 'Другое',
  };

  static const Map<String, String> incomeCategories = {
    'salary': 'Зарплата',
    'bonus': 'Бонус',
    'gift': 'Подарок',
    'freelance': 'Фриланс',
    'other-income': 'Другое',
  };

  final List<Account> _accounts = [];
  final List<FinanceTransaction> _transactions = [];

  // ============================================================
  // LOAD / SAVE
  // ============================================================

  Future<void> load() async {
    final storage = repository;

    if (storage == null) {
      return;
    }

    final saved = await storage.load();

    if (saved == null) {
      _transactions.clear();
      _accounts.clear();
      notifyListeners();
      return;
    }

    _transactions
      ..clear()
      ..addAll(saved.transactions);

    _accounts
      ..clear()
      ..addAll(saved.accounts);

    notifyListeners();
  }

  Future<void> _save() async {
    final storage = repository;

    if (storage == null) {
      return;
    }

    await storage.save(transactions: _transactions, accounts: _accounts);
  }

  // ============================================================
  // ACCOUNTS
  // ============================================================

  List<Account> get accounts {
    return List.unmodifiable(_accounts);
  }

  Account? accountById(String id) {
    for (final account in _accounts) {
      if (account.id == id) {
        return account;
      }
    }

    return null;
  }

  double accountBalance(String accountId) {
    return accountById(accountId)?.balance ?? 0;
  }

  String accountName(String? accountId) {
    if (accountId == null) {
      return 'Неизвестный счёт';
    }

    return accountById(accountId)?.name ?? 'Неизвестный счёт';
  }

  double get totalBalance {
    return _accounts
        .where((account) => account.includeInTotal)
        .fold<double>(0, (sum, account) => sum + account.balance);
  }

  Future<void> addAccount({
    required String name,
    required AccountType type,
    required double balance,
    String? bankName,
    bool includeInTotal = true,
    String currency = 'KZT',
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      return;
    }

    final cleanBankName = _cleanOptional(bankName);

    _accounts.add(
      Account(
        id: 'account-${DateTime.now().microsecondsSinceEpoch}',
        name: cleanName,
        type: type,
        balance: balance,
        currency: currency,
        bankName: cleanBankName,
        includeInTotal: includeInTotal,
      ),
    );

    notifyListeners();

    await _save();
  }

  Future<void> updateAccount({
    required String id,
    required String name,
    required AccountType type,
    required double balance,
    String? bankName,
    required bool includeInTotal,
  }) async {
    final index = _accounts.indexWhere((account) => account.id == id);

    if (index == -1) {
      return;
    }

    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      return;
    }

    final current = _accounts[index];

    _accounts[index] = Account(
      id: current.id,
      name: cleanName,
      type: type,
      balance: balance,
      currency: current.currency,
      bankName: _cleanOptional(bankName),
      includeInTotal: includeInTotal,
    );

    notifyListeners();

    await _save();
  }

  bool accountHasTransactions(String accountId) {
    return _transactions.any(
      (transaction) =>
          transaction.accountId == accountId ||
          transaction.destinationAccountId == accountId,
    );
  }

  Future<AccountDeleteResult> deleteAccount(String accountId) async {
    final index = _accounts.indexWhere((account) => account.id == accountId);

    if (index == -1) {
      return AccountDeleteResult.notFound;
    }

    if (accountHasTransactions(accountId)) {
      return AccountDeleteResult.hasTransactions;
    }

    _accounts.removeAt(index);

    notifyListeners();

    await _save();

    return AccountDeleteResult.success;
  }

  // ============================================================
  // TRANSACTIONS
  // ============================================================

  List<FinanceTransaction> get transactions {
    final result = [..._transactions];

    result.sort((a, b) => b.date.compareTo(a.date));

    return List.unmodifiable(result);
  }

  List<FinanceTransaction> get recentTransactions {
    return transactions.take(3).toList();
  }

  FinanceTransaction? transactionById(String id) {
    for (final transaction in _transactions) {
      if (transaction.id == id) {
        return transaction;
      }
    }

    return null;
  }

  String categoryName(String? id) {
    if (id == debtPaymentCategoryId) {
      return 'Долг';
    }

    if (id == null) {
      return 'Перевод';
    }

    return expenseCategories[id] ?? incomeCategories[id] ?? 'Другое';
  }

  Future<String> addTransaction({
    required FinanceTransactionType type,
    required double amount,
    required String accountId,
    String? destinationAccountId,
    String? categoryId,
    required String title,
    String? person,
    String? description,
    required DateTime date,
    String? receiptPath,
    double? latitude,
    double? longitude,
  }) async {
    final transaction = FinanceTransaction(
      id: 'transaction-${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      amount: amount,
      accountId: accountId,
      destinationAccountId:
          type == FinanceTransactionType.transfer ? destinationAccountId : null,
      categoryId: type == FinanceTransactionType.transfer ? null : categoryId,
      title: title.trim(),
      person: _cleanOptional(person),
      description: _cleanOptional(description),
      date: date,
      receiptPath: receiptPath,
      latitude: latitude,
      longitude: longitude,
    );

    _transactions.add(transaction);

    _applyTransactionToBalances(transaction);

    notifyListeners();

    await _save();

    return transaction.id;
  }

  Future<bool> updateTransaction({
    required String id,
    required FinanceTransactionType type,
    required double amount,
    required String accountId,
    String? destinationAccountId,
    String? categoryId,
    required String title,
    String? person,
    String? description,
    required DateTime date,
  }) async {
    final index = _transactions.indexWhere(
      (transaction) => transaction.id == id,
    );

    if (index == -1) {
      return false;
    }

    final oldTransaction = _transactions[index];

    _reverseTransactionFromBalances(oldTransaction);

    final updated = FinanceTransaction(
      id: oldTransaction.id,
      type: type,
      amount: amount,
      accountId: accountId,
      destinationAccountId:
          type == FinanceTransactionType.transfer ? destinationAccountId : null,
      categoryId: type == FinanceTransactionType.transfer ? null : categoryId,
      title: title.trim(),
      person: _cleanOptional(person),
      description: _cleanOptional(description),
      date: date,
      receiptPath: oldTransaction.receiptPath,
      receiptStoragePath: oldTransaction.receiptStoragePath,
      latitude: oldTransaction.latitude,
      longitude: oldTransaction.longitude,
    );

    _transactions[index] = updated;

    _applyTransactionToBalances(updated);

    notifyListeners();

    await _save();

    return true;
  }

  Future<bool> deleteTransaction(String id) async {
    final index = _transactions.indexWhere(
      (transaction) => transaction.id == id,
    );

    if (index == -1) {
      return false;
    }

    final transaction = _transactions[index];

    _reverseTransactionFromBalances(transaction);

    _transactions.removeAt(index);

    notifyListeners();

    await _save();

    return true;
  }

  Future<bool> setTransactionLocation({
    required String transactionId,
    required double latitude,
    required double longitude,
  }) async {
    final index = _transactions.indexWhere(
      (transaction) => transaction.id == transactionId,
    );

    if (index == -1) {
      return false;
    }

    _transactions[index] = _transactions[index].copyWith(
      latitude: latitude,
      longitude: longitude,
    );

    notifyListeners();

    await _save();

    return true;
  }

  Future<bool> setTransactionReceipt({
    required String transactionId,
    String? receiptPath,
  }) async {
    final index = _transactions.indexWhere(
      (transaction) => transaction.id == transactionId,
    );

    if (index == -1) {
      return false;
    }

    _transactions[index] = _transactions[index].copyWith(
      receiptPath: receiptPath,
      clearReceiptPath: receiptPath == null,
      clearReceiptStoragePath: true,
    );

    notifyListeners();

    await _save();

    return true;
  }

  Future<bool> setTransactionReceiptStoragePath({
    required String transactionId,
    required String expectedLocalPath,
    required String storagePath,
  }) async {
    final index = _transactions.indexWhere(
      (transaction) => transaction.id == transactionId,
    );
    if (index == -1 || _transactions[index].receiptPath != expectedLocalPath) {
      return false;
    }

    _transactions[index] = _transactions[index].copyWith(
      receiptStoragePath: storagePath,
    );
    await _save();
    notifyListeners();
    return true;
  }

  Future<bool> setTransactionReceiptCache({
    required String transactionId,
    required String storagePath,
    required String localPath,
  }) async {
    final index = _transactions.indexWhere(
      (transaction) => transaction.id == transactionId,
    );
    if (index == -1 || _transactions[index].receiptStoragePath != storagePath) {
      return false;
    }

    _transactions[index] = _transactions[index].copyWith(
      receiptPath: localPath,
    );
    await _save();
    notifyListeners();
    return true;
  }

  void _applyTransactionToBalances(FinanceTransaction transaction) {
    switch (transaction.type) {
      case FinanceTransactionType.expense:
        _changeBalance(transaction.accountId, -transaction.amount);
        break;

      case FinanceTransactionType.income:
        _changeBalance(transaction.accountId, transaction.amount);
        break;

      case FinanceTransactionType.transfer:
        _changeBalance(transaction.accountId, -transaction.amount);

        final destination = transaction.destinationAccountId;

        if (destination != null) {
          _changeBalance(destination, transaction.amount);
        }

        break;
    }
  }

  void _reverseTransactionFromBalances(FinanceTransaction transaction) {
    switch (transaction.type) {
      case FinanceTransactionType.expense:
        _changeBalance(transaction.accountId, transaction.amount);
        break;

      case FinanceTransactionType.income:
        _changeBalance(transaction.accountId, -transaction.amount);
        break;

      case FinanceTransactionType.transfer:
        _changeBalance(transaction.accountId, transaction.amount);

        final destination = transaction.destinationAccountId;

        if (destination != null) {
          _changeBalance(destination, -transaction.amount);
        }

        break;
    }
  }

  void _changeBalance(String accountId, double change) {
    final index = _accounts.indexWhere((account) => account.id == accountId);

    if (index == -1) {
      return;
    }

    final current = _accounts[index];

    _accounts[index] = current.copyWith(balance: current.balance + change);
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  double get monthlyIncome {
    return _monthlyTotal(FinanceTransactionType.income);
  }

  double get monthlyExpense {
    return _monthlyTotal(FinanceTransactionType.expense);
  }

  double get monthlySavings {
    return monthlyIncome - monthlyExpense;
  }

  double get savingsRate {
    if (monthlyIncome <= 0) {
      return 0;
    }

    return monthlySavings / monthlyIncome * 100;
  }

  // Оставляем второй getter для совместимости
  // с Dashboard, если там используется это имя.
  double get monthlySavingsRate {
    return savingsRate;
  }

  AccountExpenseComparison accountExpenseComparison(
    String accountId, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final currentStart = DateTime(now.year, now.month);
    final currentEnd = DateTime(now.year, now.month, now.day + 1);
    final previousStart = DateTime(now.year, now.month - 1);
    final previousMonthDays = DateTime(now.year, now.month, 0).day;
    final previousEnd = DateTime(
      now.year,
      now.month - 1,
      (now.day < previousMonthDays ? now.day : previousMonthDays) + 1,
    );

    double totalIn(DateTime start, DateTime end) => _transactions
        .where(
          (transaction) =>
              transaction.accountId == accountId &&
              transaction.type == FinanceTransactionType.expense &&
              transaction.categoryId != debtPaymentCategoryId &&
              !transaction.date.isBefore(start) &&
              transaction.date.isBefore(end),
        )
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    final currentExpense = totalIn(currentStart, currentEnd);
    final previousExpense = totalIn(previousStart, previousEnd);

    return AccountExpenseComparison(
      currentExpense: currentExpense,
      previousExpense: previousExpense,
      percentChange:
          previousExpense == 0
              ? null
              : (currentExpense - previousExpense) / previousExpense * 100,
    );
  }

  double _monthlyTotal(FinanceTransactionType type) {
    final now = DateTime.now();

    return _transactions
        .where(
          (transaction) =>
              transaction.type == type &&
              transaction.categoryId != debtPaymentCategoryId &&
              transaction.date.year == now.year &&
              transaction.date.month == now.month,
        )
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  List<double> expenseChartValues({int days = 8}) {
    return expenseChartSeries(days: days).values;
  }

  ExpenseChartSeries expenseChartSeries({int days = 8, DateTime? now}) {
    if (days <= 0) {
      return const ExpenseChartSeries(dates: [], values: []);
    }

    final current = now ?? DateTime.now();
    final dates = List.generate(
      days,
      (index) =>
          DateTime(current.year, current.month, current.day - days + index + 1),
    );
    final totals = _expenseTotalsForDates(dates);
    return ExpenseChartSeries(
      dates: dates,
      values: [for (final date in dates) totals[date] ?? 0],
    );
  }

  // ============================================================
  // ANALYTICS
  // ============================================================

  AnalyticsSnapshot analyticsSnapshot(AnalyticsPeriod period, {DateTime? at}) {
    final now = at ?? DateTime.now();

    final currentRange = _currentRange(period, now);

    final previousRange = _previousRange(period, currentRange);

    final currentTransactions = _transactionsInRange(currentRange);

    final previousTransactions = _transactionsInRange(previousRange);

    final income = _sumByType(
      currentTransactions,
      FinanceTransactionType.income,
    );

    final expense = _sumByType(
      currentTransactions,
      FinanceTransactionType.expense,
    );

    final savings = income - expense;

    final currentSavingsRate = income <= 0 ? 0.0 : savings / income * 100;

    final previousExpense = _sumByType(
      previousTransactions,
      FinanceTransactionType.expense,
    );

    final hasPreviousData = previousTransactions.any(
      (transaction) => transaction.categoryId != debtPaymentCategoryId,
    );

    double expenseChangePercent = 0;

    if (previousExpense > 0) {
      expenseChangePercent =
          (expense - previousExpense) / previousExpense * 100;
    } else if (expense > 0) {
      expenseChangePercent = 100;
    }

    final categoryMap = <String, double>{};

    for (final transaction in currentTransactions) {
      if (transaction.type != FinanceTransactionType.expense ||
          transaction.categoryId == debtPaymentCategoryId) {
        continue;
      }

      final categoryId = transaction.categoryId ?? 'other-expense';

      categoryMap.update(
        categoryId,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final categories =
        categoryMap.entries
            .map(
              (entry) => FinanceCategoryTotal(
                id: entry.key,
                name: categoryName(entry.key),
                amount: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    final chart = _buildChart(period, now);

    return AnalyticsSnapshot(
      period: period,
      income: income,
      expense: expense,
      savings: savings,
      savingsRate: currentSavingsRate,
      previousExpense: previousExpense,
      expenseChangePercent: expenseChangePercent,
      hasPreviousData: hasPreviousData,
      chartValues: chart.values,
      chartDates: chart.dates,
      chartLabels: chart.labels,
      categories: categories,
    );
  }

  _Range _currentRange(AnalyticsPeriod period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case AnalyticsPeriod.week:
        return _Range(
          start: today.subtract(const Duration(days: 6)),
          end: today.add(const Duration(days: 1)),
        );

      case AnalyticsPeriod.month:
        final start = DateTime(now.year, now.month, 1);

        final end = DateTime(now.year, now.month + 1, 1);

        return _Range(start: start, end: end);

      case AnalyticsPeriod.year:
        return _Range(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year + 1, 1, 1),
        );
    }
  }

  _Range _previousRange(AnalyticsPeriod period, _Range current) {
    switch (period) {
      case AnalyticsPeriod.week:
        return _Range(
          start: current.start.subtract(const Duration(days: 7)),
          end: current.start,
        );

      case AnalyticsPeriod.month:
        final previousMonth = DateTime(
          current.start.year,
          current.start.month - 1,
          1,
        );

        return _Range(start: previousMonth, end: current.start);

      case AnalyticsPeriod.year:
        return _Range(
          start: DateTime(current.start.year - 1, 1, 1),
          end: current.start,
        );
    }
  }

  List<FinanceTransaction> _transactionsInRange(_Range range) {
    return _transactions
        .where(
          (transaction) =>
              !transaction.date.isBefore(range.start) &&
              transaction.date.isBefore(range.end),
        )
        .toList();
  }

  double _sumByType(
    List<FinanceTransaction> source,
    FinanceTransactionType type,
  ) {
    return source
        .where(
          (transaction) =>
              transaction.type == type &&
              transaction.categoryId != debtPaymentCategoryId,
        )
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  _ChartData _buildChart(AnalyticsPeriod period, DateTime now) {
    switch (period) {
      case AnalyticsPeriod.week:
        return _buildWeekChart(now);

      case AnalyticsPeriod.month:
        return _buildMonthChart(now);

      case AnalyticsPeriod.year:
        return _buildYearChart(now);
    }
  }

  _ChartData _buildWeekChart(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    final dates = <DateTime>[];
    final labels = <String>[];

    for (var i = 0; i < 7; i++) {
      final day = DateTime(today.year, today.month, today.day - 6 + i);

      dates.add(day);

      if (i == 0 || i == 3 || i == 6) {
        labels.add('${day.day}.${day.month}');
      } else {
        labels.add('');
      }
    }

    final totals = _expenseTotalsForDates(dates);
    return _ChartData(
      values: [for (final date in dates) totals[date] ?? 0],
      dates: dates,
      labels: labels,
    );
  }

  _ChartData _buildMonthChart(DateTime now) {
    final dates = <DateTime>[];
    final labels = <String>[];

    final middle = (now.day / 2).ceil();

    for (var day = 1; day <= now.day; day++) {
      final date = DateTime(now.year, now.month, day);

      dates.add(date);

      if (day == 1 || day == middle || day == now.day) {
        labels.add('$day ${_shortMonth(now.month)}');
      } else {
        labels.add('');
      }
    }

    final totals = _expenseTotalsForDates(dates);
    return _ChartData(
      values: [for (final date in dates) totals[date] ?? 0],
      dates: dates,
      labels: labels,
    );
  }

  _ChartData _buildYearChart(DateTime now) {
    final values = <double>[];
    final dates = <DateTime>[];
    final labels = <String>[];

    final middle = (now.month / 2).ceil();
    final totals = <int, double>{};
    for (final transaction in _transactions) {
      if (transaction.type == FinanceTransactionType.expense &&
          transaction.categoryId != debtPaymentCategoryId &&
          transaction.date.year == now.year &&
          transaction.date.month <= now.month) {
        totals.update(
          transaction.date.month,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
    }

    for (var month = 1; month <= now.month; month++) {
      dates.add(DateTime(now.year, month, 1));
      values.add(totals[month] ?? 0);

      if (month == 1 || month == middle || month == now.month) {
        labels.add(_shortMonth(month));
      } else {
        labels.add('');
      }
    }

    return _ChartData(values: values, dates: dates, labels: labels);
  }

  Map<DateTime, double> _expenseTotalsForDates(List<DateTime> dates) {
    final requestedDates = dates.toSet();
    final totals = <DateTime, double>{};
    for (final transaction in _transactions) {
      if (transaction.type != FinanceTransactionType.expense ||
          transaction.categoryId == debtPaymentCategoryId) {
        continue;
      }
      final date = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      if (!requestedDates.contains(date)) continue;
      totals.update(
        date,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return totals;
  }

  String _shortMonth(int month) {
    const months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];

    if (month < 1 || month > 12) {
      return '';
    }

    return months[month - 1];
  }

  String? _cleanOptional(String? value) {
    if (value == null) {
      return null;
    }

    final clean = value.trim();

    if (clean.isEmpty) {
      return null;
    }

    return clean;
  }
}

class _Range {
  final DateTime start;
  final DateTime end;

  const _Range({required this.start, required this.end});
}

class _ChartData {
  final List<double> values;
  final List<DateTime> dates;
  final List<String> labels;

  const _ChartData({
    required this.values,
    required this.dates,
    required this.labels,
  });
}
