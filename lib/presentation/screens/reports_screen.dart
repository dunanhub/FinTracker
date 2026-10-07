import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/report_export_service.dart';
import '../../domain/entities/finance_transaction.dart';
import '../controllers/finance_controller.dart';

enum ReportPeriod { week, month, year, custom }

enum ReportTransactionFilter { all, income, expense, transfer }

enum _ReportExportFormat { csv, excel, pdf }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const String _allAccounts = '__all_accounts__';

  ReportPeriod _period = ReportPeriod.month;

  ReportTransactionFilter _typeFilter = ReportTransactionFilter.all;

  String _accountId = _allAccounts;

  late DateTime _customStart;
  late DateTime _customEnd;

  _ReportExportFormat? _exporting;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _customStart = DateTime(now.year, now.month, 1);

    _customEnd = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final finance = context.watch<FinanceController>();

    final range = _activeRange();

    final transactions = _filteredTransactions(finance, range);

    final summary = _buildSummary(transactions);

    return Scaffold(
      appBar: AppBar(title: const Text('Отчёты')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
        children: [
          _ReportHeader(range: range, operationCount: transactions.length),

          const SizedBox(height: 24),

          Text('Период', style: theme.textTheme.titleLarge),

          const SizedBox(height: 11),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _PeriodChip(
                  title: 'Неделя',
                  selected: _period == ReportPeriod.week,
                  onTap: () {
                    setState(() {
                      _period = ReportPeriod.week;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  title: 'Месяц',
                  selected: _period == ReportPeriod.month,
                  onTap: () {
                    setState(() {
                      _period = ReportPeriod.month;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  title: 'Год',
                  selected: _period == ReportPeriod.year,
                  onTap: () {
                    setState(() {
                      _period = ReportPeriod.year;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  title: 'Свой период',
                  selected: _period == ReportPeriod.custom,
                  onTap: _pickCustomRange,
                  icon: Icons.calendar_month_outlined,
                ),
              ],
            ),
          ),

          if (_period == ReportPeriod.custom) ...[
            const SizedBox(height: 12),
            _CustomPeriodCard(
              start: _customStart,
              end: _customEnd,
              onTap: _pickCustomRange,
            ),
          ],

          const SizedBox(height: 28),

          Text('Фильтры', style: theme.textTheme.titleLarge),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _validAccount(finance),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Счёт',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: _allAccounts,
                      child: Text('Все счета'),
                    ),
                    ...finance.accounts.map((account) {
                      return DropdownMenuItem<String>(
                        value: account.id,
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _accountId = value;
                    });
                  },
                ),

                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Тип операций',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                ),

                const SizedBox(height: 9),

                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _FilterChip(
                      title: 'Все',
                      selected: _typeFilter == ReportTransactionFilter.all,
                      onTap: () {
                        setState(() {
                          _typeFilter = ReportTransactionFilter.all;
                        });
                      },
                    ),
                    _FilterChip(
                      title: 'Доходы',
                      selected: _typeFilter == ReportTransactionFilter.income,
                      onTap: () {
                        setState(() {
                          _typeFilter = ReportTransactionFilter.income;
                        });
                      },
                    ),
                    _FilterChip(
                      title: 'Расходы',
                      selected: _typeFilter == ReportTransactionFilter.expense,
                      onTap: () {
                        setState(() {
                          _typeFilter = ReportTransactionFilter.expense;
                        });
                      },
                    ),
                    _FilterChip(
                      title: 'Переводы',
                      selected: _typeFilter == ReportTransactionFilter.transfer,
                      onTap: () {
                        setState(() {
                          _typeFilter = ReportTransactionFilter.transfer;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text('Сводка', style: theme.textTheme.titleLarge),

          const SizedBox(height: 12),

          _SummaryGrid(summary: summary),

          if (summary.debtIncome > 0 || summary.debtExpense > 0) ...[
            const SizedBox(height: 10),
            _DebtSummaryCard(
              income: summary.debtIncome,
              expense: summary.debtExpense,
            ),
          ],

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: Text('Экспорт', style: theme.textTheme.titleLarge),
              ),
              Text(
                '${transactions.length} операций',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _ExportButton(
                  title: 'CSV',
                  icon: Icons.table_rows_outlined,
                  loading: _exporting == _ReportExportFormat.csv,
                  disabled: _exporting != null,
                  onTap: () {
                    _export(
                      format: _ReportExportFormat.csv,
                      finance: finance,
                      transactions: transactions,
                      summary: summary,
                      range: range,
                    );
                  },
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _ExportButton(
                  title: 'Excel',
                  icon: Icons.grid_on_outlined,
                  loading: _exporting == _ReportExportFormat.excel,
                  disabled: _exporting != null,
                  onTap: () {
                    _export(
                      format: _ReportExportFormat.excel,
                      finance: finance,
                      transactions: transactions,
                      summary: summary,
                      range: range,
                    );
                  },
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _ExportButton(
                  title: 'PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  loading: _exporting == _ReportExportFormat.pdf,
                  disabled: _exporting != null,
                  onTap: () {
                    _export(
                      format: _ReportExportFormat.pdf,
                      finance: finance,
                      transactions: transactions,
                      summary: summary,
                      range: range,
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          Text('Операции', style: theme.textTheme.titleLarge),

          const SizedBox(height: 12),

          if (transactions.isEmpty)
            const _EmptyReport()
          else
            ...transactions.map((transaction) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _TransactionRow(
                  transaction: transaction,
                  finance: finance,
                ),
              );
            }),
        ],
      ),
    );
  }

  String _validAccount(FinanceController finance) {
    if (_accountId == _allAccounts) {
      return _allAccounts;
    }

    if (finance.accounts.any((account) => account.id == _accountId)) {
      return _accountId;
    }

    _accountId = _allAccounts;

    return _allAccounts;
  }

  DateTimeRange _activeRange() {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    switch (_period) {
      case ReportPeriod.week:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );

      case ReportPeriod.month:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: today,
        );

      case ReportPeriod.year:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: today);

      case ReportPeriod.custom:
        return DateTimeRange(start: _customStart, end: _customEnd);
    }
  }

  List<FinanceTransaction> _filteredTransactions(
    FinanceController finance,
    DateTimeRange range,
  ) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );

    final endExclusive = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    ).add(const Duration(days: 1));

    final result =
        finance.transactions.where((transaction) {
          final inPeriod =
              !transaction.date.isBefore(start) &&
              transaction.date.isBefore(endExclusive);

          if (!inPeriod) {
            return false;
          }

          if (_accountId != _allAccounts) {
            final matchesAccount =
                transaction.accountId == _accountId ||
                transaction.destinationAccountId == _accountId;

            if (!matchesAccount) {
              return false;
            }
          }

          switch (_typeFilter) {
            case ReportTransactionFilter.all:
              return true;

            case ReportTransactionFilter.income:
              return transaction.type == FinanceTransactionType.income;

            case ReportTransactionFilter.expense:
              return transaction.type == FinanceTransactionType.expense;

            case ReportTransactionFilter.transfer:
              return transaction.type == FinanceTransactionType.transfer;
          }
        }).toList();

    result.sort((a, b) => b.date.compareTo(a.date));

    return result;
  }

  _ReportSummary _buildSummary(List<FinanceTransaction> transactions) {
    var income = 0.0;
    var expense = 0.0;

    var debtIncome = 0.0;
    var debtExpense = 0.0;

    var transfers = 0.0;

    for (final transaction in transactions) {
      final isDebt =
          transaction.categoryId == FinanceController.debtPaymentCategoryId;

      if (isDebt) {
        if (transaction.type == FinanceTransactionType.income) {
          debtIncome += transaction.amount;
        } else if (transaction.type == FinanceTransactionType.expense) {
          debtExpense += transaction.amount;
        }

        continue;
      }

      switch (transaction.type) {
        case FinanceTransactionType.income:
          income += transaction.amount;
          break;

        case FinanceTransactionType.expense:
          expense += transaction.amount;
          break;

        case FinanceTransactionType.transfer:
          transfers += transaction.amount;
          break;
      }
    }

    return _ReportSummary(
      income: income,
      expense: expense,
      net: income - expense,
      debtIncome: debtIncome,
      debtExpense: debtExpense,
      transfers: transfers,
    );
  }

  Future<void> _pickCustomRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _customStart, end: _customEnd),
      helpText: 'Выберите период отчёта',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      saveText: 'Готово',
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _customStart = result.start;

      _customEnd = result.end;

      _period = ReportPeriod.custom;
    });
  }

  Future<void> _export({
    required _ReportExportFormat format,
    required FinanceController finance,
    required List<FinanceTransaction> transactions,
    required _ReportSummary summary,
    required DateTimeRange range,
  }) async {
    if (_exporting != null) {
      return;
    }

    setState(() {
      _exporting = format;
    });

    final periodLabel =
        '${_dateText(range.start)} — '
        '${_dateText(range.end)}';

    final rows =
        transactions.map((transaction) {
          return ReportExportRow(
            date: transaction.date,
            type: _transactionTypeName(transaction),
            title: transaction.title,
            category: finance.categoryName(transaction.categoryId),
            account: finance.accountName(transaction.accountId),
            destinationAccount:
                transaction.destinationAccountId == null
                    ? ''
                    : finance.accountName(transaction.destinationAccountId),
            person: transaction.person ?? '',
            description: transaction.description ?? '',
            amount: transaction.amount,
          );
        }).toList();

    final exportSummary = ReportExportSummary(
      periodLabel: periodLabel,
      operationCount: transactions.length,
      income: summary.income,
      expense: summary.expense,
      net: summary.net,
      debtIncome: summary.debtIncome,
      debtExpense: summary.debtExpense,
      transfers: summary.transfers,
    );

    final fileName =
        'fintracker_${_fileDate(range.start)}'
        '_${_fileDate(range.end)}';

    try {
      switch (format) {
        case _ReportExportFormat.csv:
          await ReportExportService.shareCsv(
            summary: exportSummary,
            rows: rows,
            fileName: fileName,
          );
          break;

        case _ReportExportFormat.excel:
          await ReportExportService.shareExcel(
            summary: exportSummary,
            rows: rows,
            fileName: fileName,
          );
          break;

        case _ReportExportFormat.pdf:
          await ReportExportService.sharePdf(
            summary: exportSummary,
            rows: rows,
            fileName: fileName,
          );
          break;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Не удалось сформировать отчёт');
    } finally {
      if (mounted) {
        setState(() {
          _exporting = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

class _ReportHeader extends StatelessWidget {
  final DateTimeRange range;
  final int operationCount;

  const _ReportHeader({required this.range, required this.operationCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.description_outlined,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Финансовый отчёт', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${_dateText(range.start)} — '
                  '${_dateText(range.end)}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '$operationCount',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _PeriodChip({
    required this.title,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected ? theme.colorScheme.primary : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected
                      ? Colors.transparent
                      : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color:
                      selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: TextStyle(
                  color:
                      selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Text(title),
      selected: selected,
      onSelected: (_) {
        onTap();
      },
      showCheckmark: false,
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      side: BorderSide(
        color:
            selected
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : theme.colorScheme.outlineVariant,
      ),
      labelStyle: TextStyle(
        color:
            selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CustomPeriodCard extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final VoidCallback onTap;

  const _CustomPeriodCard({
    required this.start,
    required this.end,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.date_range_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_dateText(start)} — '
                  '${_dateText(end)}',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 12),
                ),
              ),
              const Icon(Icons.edit_calendar_outlined, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final _ReportSummary summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final colors = context.finColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'Доходы',
                amount: summary.income,
                icon: Icons.south_west_rounded,
                color: colors.income,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'Расходы',
                amount: summary.expense,
                icon: Icons.north_east_rounded,
                color: colors.expense,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'Результат',
                amount: summary.net,
                icon: Icons.account_balance_wallet_outlined,
                color: summary.net >= 0 ? colors.income : colors.expense,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'Переводы',
                amount: summary.transfers,
                icon: Icons.swap_horiz_rounded,
                color: colors.transfer,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 19),
          ),

          const SizedBox(height: 14),

          Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9)),

          const SizedBox(height: 4),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_formatAmount(amount)} ₸',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtSummaryCard extends StatelessWidget {
  final double income;
  final double expense;

  const _DebtSummaryCard({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = context.finColors;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.handshake_outlined,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Долги', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Мне вернули '
                  '${_formatAmount(income)} ₸',
                  style: TextStyle(
                    color: colors.income,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Я выплатил '
                  '${_formatAmount(expense)} ₸',
                  style: TextStyle(
                    color: colors.expense,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;

  const _ExportButton({
    required this.title,
    required this.icon,
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton(
      onPressed: disabled ? null : onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 21, color: theme.colorScheme.primary),

          const SizedBox(height: 6),

          Text(loading ? '...' : title, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final FinanceTransaction transaction;

  final FinanceController finance;

  const _TransactionRow({required this.transaction, required this.finance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = context.finColors;

    final isDebt =
        transaction.categoryId == FinanceController.debtPaymentCategoryId;

    final Color color;

    switch (transaction.type) {
      case FinanceTransactionType.income:
        color = colors.income;
        break;

      case FinanceTransactionType.expense:
        color = colors.expense;
        break;

      case FinanceTransactionType.transfer:
        color = colors.transfer;
        break;
    }

    final accountText =
        transaction.type == FinanceTransactionType.transfer
            ? '${finance.accountName(transaction.accountId)}'
                ' → '
                '${finance.accountName(transaction.destinationAccountId)}'
            : finance.accountName(transaction.accountId);

    final prefix =
        transaction.type == FinanceTransactionType.income
            ? '+'
            : transaction.type == FinanceTransactionType.expense
            ? '−'
            : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isDebt
                  ? Icons.handshake_outlined
                  : transaction.type == FinanceTransactionType.income
                  ? Icons.south_west_rounded
                  : transaction.type == FinanceTransactionType.expense
                  ? Icons.north_east_rounded
                  : Icons.swap_horiz_rounded,
              color: color,
              size: 19,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 12),
                ),

                const SizedBox(height: 3),

                Text(
                  accountText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
                ),

                const SizedBox(height: 2),

                Text(
                  _dateTimeText(transaction.date),
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 8),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$prefix'
                '${_formatAmount(transaction.amount)} ₸',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _transactionTypeName(transaction),
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 34,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text('Операций нет', style: theme.textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            'Попробуй изменить период или фильтры.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ReportSummary {
  final double income;
  final double expense;
  final double net;

  final double debtIncome;
  final double debtExpense;

  final double transfers;

  const _ReportSummary({
    required this.income,
    required this.expense,
    required this.net,
    required this.debtIncome,
    required this.debtExpense,
    required this.transfers,
  });
}

String _transactionTypeName(FinanceTransaction transaction) {
  if (transaction.categoryId == FinanceController.debtPaymentCategoryId) {
    if (transaction.type == FinanceTransactionType.income) {
      return 'Возврат долга';
    }

    return 'Выплата долга';
  }

  switch (transaction.type) {
    case FinanceTransactionType.income:
      return 'Доход';

    case FinanceTransactionType.expense:
      return 'Расход';

    case FinanceTransactionType.transfer:
      return 'Перевод';
  }
}

String _dateText(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String _dateTimeText(DateTime date) {
  return '${_dateText(date)} · '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _fileDate(DateTime date) {
  return '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _formatAmount(double value) {
  final rounded = value.round();

  final negative = rounded < 0;

  final digits = rounded.abs().toString();

  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;

    buffer.write(digits[i]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }

  return '${negative ? '−' : ''}'
      '${buffer.toString()}';
}
