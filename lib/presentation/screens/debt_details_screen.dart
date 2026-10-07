import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/finance_transaction.dart';
import '../controllers/debt_controller.dart';
import '../controllers/finance_controller.dart';
import 'add_debt_screen.dart';

class DebtDetailsScreen extends StatelessWidget {
  final String debtId;

  const DebtDetailsScreen({super.key, required this.debtId});

  @override
  Widget build(BuildContext context) {
    final debtController = context.watch<DebtController>();

    final debt = debtController.debtById(debtId);

    if (debt == null) {
      return const Scaffold(body: Center(child: Text('Долг не найден')));
    }

    final theme = Theme.of(context);
    final colors = context.finColors;

    final finance = context.watch<FinanceController>();

    final color = debt.type == DebtType.iOwe ? colors.expense : colors.income;

    final payments = [...debt.payments]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Долг'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddDebtScreen(debt: debt)),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        debt.type == DebtType.iOwe
                            ? Icons.north_east_rounded
                            : Icons.south_west_rounded,
                        color: color,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(debt.person, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 3),
                          Text(
                            debt.type == DebtType.iOwe
                                ? 'Я должен'
                                : 'Мне должны',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  debt.isPaid ? 'Погашено' : 'Осталось',
                  style: theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 5),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_formatAmount(debt.remainingAmount)} ₸',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),

                const SizedBox(height: 17),

                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: debt.progress,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.35),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  '${_formatAmount(debt.paidAmount)} из '
                  '${_formatAmount(debt.originalAmount)} ₸ погашено',
                  style: theme.textTheme.bodyMedium,
                ),

                if (debt.deadline != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 17),
                      const SizedBox(width: 7),
                      Text('До ${_dateText(debt.deadline!)}'),
                    ],
                  ),
                ],

                if (debt.note != null && debt.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(debt.note!, style: theme.textTheme.bodyMedium),
                ],

                if (!debt.isPaid) ...[
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          finance.accounts.isEmpty
                              ? null
                              : () {
                                showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  showDragHandle: true,
                                  builder: (_) => _DebtPaymentSheet(debt: debt),
                                );
                              },
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(
                        finance.accounts.isEmpty
                            ? 'Сначала добавь счёт'
                            : debt.type == DebtType.iOwe
                            ? 'Я выплатил'
                            : 'Мне вернули',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text('История выплат', style: theme.textTheme.titleLarge),

          const SizedBox(height: 12),

          if (payments.isEmpty)
            Text('Пока выплат нет', style: theme.textTheme.bodyMedium)
          else
            ...payments.map((payment) {
              final account =
                  payment.accountId == null
                      ? null
                      : finance.accountById(payment.accountId!);

              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: color,
                          size: 18,
                        ),
                      ),

                      const SizedBox(width: 11),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account?.name ?? 'Выплата',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _dateTimeText(payment.date),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      Text(
                        '${_formatAmount(payment.amount)} ₸',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _DebtPaymentSheet extends StatefulWidget {
  final Debt debt;

  const _DebtPaymentSheet({required this.debt});

  @override
  State<_DebtPaymentSheet> createState() => _DebtPaymentSheetState();
}

class _DebtPaymentSheetState extends State<_DebtPaymentSheet> {
  late final TextEditingController _amountController;

  String? _accountId;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_accountId != null) {
      return;
    }

    final accounts = context.read<FinanceController>().accounts;

    if (accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final finance = context.watch<FinanceController>();

    final accounts = finance.accounts;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.debt.type == DebtType.iOwe
                    ? 'Выплатить долг'
                    : 'Получить возврат',
                style: theme.textTheme.titleLarge,
              ),

              const SizedBox(height: 4),

              Text(widget.debt.person, style: theme.textTheme.bodyMedium),

              const SizedBox(height: 7),

              Text(
                'Осталось '
                '${_formatAmount(widget.debt.remainingAmount)} ₸',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Сумма',
                  suffixText: '₸',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),

              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: _validAccountId(accounts),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText:
                      widget.debt.type == DebtType.iOwe
                          ? 'С какого счёта'
                          : 'На какой счёт',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                ),
                items:
                    accounts.map((account) {
                      return DropdownMenuItem<String>(
                        value: account.id,
                        child: Text(
                          '${account.name} · '
                          '${_formatAmount(account.balance)} ₸',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _accountId = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon:
                      _saving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(
                            widget.debt.type == DebtType.iOwe
                                ? Icons.north_east_rounded
                                : Icons.south_west_rounded,
                          ),
                  label: Text(
                    _saving
                        ? 'Сохраняем...'
                        : widget.debt.type == DebtType.iOwe
                        ? 'Выплатить'
                        : 'Получить',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validAccountId(List<Account> accounts) {
    if (accounts.isEmpty) {
      return null;
    }

    if (_accountId != null &&
        accounts.any((account) => account.id == _accountId)) {
      return _accountId;
    }

    _accountId = accounts.first.id;

    return _accountId;
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final amount = double.tryParse(
      _amountController.text.replaceAll(',', '.').replaceAll(' ', ''),
    );

    if (amount == null || amount <= 0) {
      _message('Введите сумму');

      return;
    }

    if (amount > widget.debt.remainingAmount) {
      _message(
        'Остаток долга — '
        '${_formatAmount(widget.debt.remainingAmount)} ₸',
      );

      return;
    }

    final finance = context.read<FinanceController>();

    final debtController = context.read<DebtController>();

    final account =
        _accountId == null ? null : finance.accountById(_accountId!);

    if (account == null) {
      _message('Выберите счёт');

      return;
    }

    if (widget.debt.type == DebtType.iOwe && account.balance < amount) {
      _message(
        'Недостаточно денег на счёте '
        '«${account.name}»',
      );

      return;
    }

    setState(() {
      _saving = true;
    });

    String? transactionId;

    try {
      transactionId = await finance.addTransaction(
        type:
            widget.debt.type == DebtType.iOwe
                ? FinanceTransactionType.expense
                : FinanceTransactionType.income,
        amount: amount,
        accountId: account.id,
        categoryId: FinanceController.debtPaymentCategoryId,
        title:
            widget.debt.type == DebtType.iOwe
                ? 'Выплата долга · ${widget.debt.person}'
                : 'Возврат долга · ${widget.debt.person}',
        person: widget.debt.person,
        description: 'Погашение долга',
        date: DateTime.now(),
      );

      final success = await debtController.addPayment(
        debtId: widget.debt.id,
        amount: amount,
        accountId: account.id,
        transactionId: transactionId,
      );

      if (!success) {
        await finance.deleteTransaction(transactionId);

        if (!mounted) {
          return;
        }

        setState(() {
          _saving = false;
        });

        _message('Не удалось сохранить выплату');

        return;
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (_) {
      if (transactionId != null) {
        try {
          await finance.deleteTransaction(transactionId);
        } catch (_) {
          // Не маскируем основную ошибку.
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _message('Не удалось сохранить выплату');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
      );
  }
}

String _dateText(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String _dateTimeText(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');

  final minute = date.minute.toString().padLeft(2, '0');

  return '${_dateText(date)} · $hour:$minute';
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
