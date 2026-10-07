import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/entities/savings_goal.dart';
import '../controllers/finance_controller.dart';
import '../controllers/goal_controller.dart';
import 'add_goal_screen.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final controller = context.watch<GoalController>();

    final goals = controller.goals;

    final totalTarget = goals.fold<double>(
      0,
      (sum, goal) => sum + goal.targetAmount,
    );

    final totalCurrent = goals.fold<double>(
      0,
      (sum, goal) => sum + goal.currentAmount,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Финансовые цели')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          _GoalsSummary(current: totalCurrent, target: totalTarget),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: Text('Мои цели', style: theme.textTheme.titleLarge),
              ),
              Text('${goals.length}', style: theme.textTheme.bodyMedium),
            ],
          ),

          const SizedBox(height: 14),

          if (goals.isEmpty)
            const _EmptyGoals()
          else
            ...goals.map((goal) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GoalCard(
                  goal: goal,
                  controller: controller,
                  onTap: () {
                    _openGoal(context, goal);
                  },
                  onTopUp:
                      controller.remaining(goal) <= 0
                          ? null
                          : () {
                            _topUpGoal(context, goal);
                          },
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openGoal(context, null);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить'),
      ),
    );
  }

  void _openGoal(BuildContext context, SavingsGoal? goal) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) {
          return AddGoalScreen(goal: goal);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _topUpGoal(BuildContext context, SavingsGoal goal) async {
    final finance = context.read<FinanceController>();

    final goalController = context.read<GoalController>();

    final linkedAccount =
        goal.linkedAccountId == null
            ? null
            : finance.accountById(goal.linkedAccountId!);

    final sourceAccounts =
        linkedAccount == null
            ? <Account>[]
            : finance.accounts
                .where((account) => account.id != linkedAccount.id)
                .toList();

    final request = await showModalBottomSheet<_GoalTopUpRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _GoalTopUpSheet(
          goal: goal,
          linkedAccount: linkedAccount,
          sourceAccounts: sourceAccounts,
          remaining: goalController.remaining(goal),
        );
      },
    );

    if (request == null || !context.mounted) {
      return;
    }

    try {
      if (linkedAccount != null) {
        final sourceId = request.sourceAccountId;

        if (sourceId == null) {
          return;
        }

        await finance.addTransaction(
          type: FinanceTransactionType.transfer,
          amount: request.amount,
          accountId: sourceId,
          destinationAccountId: linkedAccount.id,
          title: 'Цель: ${goal.name}',
          date: DateTime.now(),
        );
      }

      final success = await goalController.addMoney(
        id: goal.id,
        amount: request.amount,
      );

      if (!context.mounted) {
        return;
      }

      if (!success) {
        _message(context, 'Не удалось пополнить цель');

        return;
      }

      _message(
        context,
        'Цель пополнена на '
        '${_formatAmount(request.amount)} ₸',
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      _message(context, 'Не удалось выполнить пополнение');
    }
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

class _GoalTopUpSheet extends StatefulWidget {
  final SavingsGoal goal;
  final Account? linkedAccount;

  final List<Account> sourceAccounts;

  final double remaining;

  const _GoalTopUpSheet({
    required this.goal,
    required this.linkedAccount,
    required this.sourceAccounts,
    required this.remaining,
  });

  @override
  State<_GoalTopUpSheet> createState() => _GoalTopUpSheetState();
}

class _GoalTopUpSheetState extends State<_GoalTopUpSheet> {
  late final TextEditingController _amountController;

  String? _selectedSourceId;

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController();

    if (widget.sourceAccounts.isNotEmpty) {
      _selectedSourceId = widget.sourceAccounts.first.id;
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

    final linkedAccount = widget.linkedAccount;

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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Пополнить цель',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.goal.name,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Осталось '
                      '${_formatAmount(widget.remaining)} ₸',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

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
                  labelText: 'Сумма пополнения',
                  suffixText: '₸',
                  prefixIcon: Icon(Icons.add_card_rounded),
                ),
              ),

              if (linkedAccount != null) ...[
                const SizedBox(height: 18),

                Text(
                  'Перевод на '
                  '${linkedAccount.name}',
                  style: theme.textTheme.titleMedium,
                ),

                const SizedBox(height: 5),

                Text(
                  'FinTracker создаст перевод между твоими счетами.',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),

                const SizedBox(height: 14),

                if (widget.sourceAccounts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.error,
                        ),

                        const SizedBox(width: 10),

                        const Expanded(
                          child: Text(
                            'Нет другого счёта, '
                            'с которого можно '
                            'сделать перевод.',
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSourceId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Откуда перевести',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items:
                        widget.sourceAccounts.map((account) {
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
                        _selectedSourceId = value;
                      });
                    },
                  ),
              ],

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      linkedAccount != null && widget.sourceAccounts.isEmpty
                          ? null
                          : _submit,
                  icon: const Icon(Icons.savings_outlined),
                  label: const Text('Пополнить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final amount = _parseAmount(_amountController.text);

    if (amount == null || amount <= 0) {
      _showMessage('Введите сумму пополнения');

      return;
    }

    if (amount > widget.remaining) {
      _showMessage(
        'До цели осталось только '
        '${_formatAmount(widget.remaining)} ₸',
      );

      return;
    }

    if (widget.linkedAccount != null) {
      Account? sourceAccount;

      if (_selectedSourceId != null) {
        for (final account in widget.sourceAccounts) {
          if (account.id == _selectedSourceId) {
            sourceAccount = account;

            break;
          }
        }
      }

      if (sourceAccount == null) {
        _showMessage('Выберите счёт');

        return;
      }

      if (sourceAccount.balance < amount) {
        _showMessage(
          'Недостаточно денег на счёте '
          '«${sourceAccount.name}»',
        );

        return;
      }
    }

    Navigator.of(context).pop(
      _GoalTopUpRequest(amount: amount, sourceAccountId: _selectedSourceId),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

class _GoalTopUpRequest {
  final double amount;
  final String? sourceAccountId;

  const _GoalTopUpRequest({required this.amount, this.sourceAccountId});
}

class _GoalsSummary extends StatelessWidget {
  final double current;
  final double target;

  const _GoalsSummary({required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final progress =
        target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Общий прогресс', style: theme.textTheme.bodyMedium),

          const SizedBox(height: 6),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_formatAmount(current)} / '
              '${_formatAmount(target)} ₸',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 25),
            ),
          ),

          const SizedBox(height: 18),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.outlineVariant.withValues(
                alpha: 0.35,
              ),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            '${(progress * 100).round()}% накоплено',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;

  final GoalController controller;

  final VoidCallback onTap;
  final VoidCallback? onTopUp;

  const _GoalCard({
    required this.goal,
    required this.controller,
    required this.onTap,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final finance = context.read<FinanceController>();

    final progress = controller.progress(goal);

    final remaining = controller.remaining(goal);

    final monthly = controller.monthlyRequired(goal);

    final completed = progress >= 1;

    final linkedAccount =
        goal.linkedAccountId == null
            ? null
            : finance.accountById(goal.linkedAccountId!);

    final color =
        completed
            ? theme.colorScheme.primary
            : progress >= 0.75
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      completed ? Icons.check_rounded : Icons.flag_outlined,
                      color: color,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),

                        const SizedBox(height: 3),

                        Text(
                          completed
                              ? 'Цель достигнута'
                              : 'До ${_dateText(goal.deadline)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),

            if (linkedAccount != null) ...[
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_outlined,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        linkedAccount.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_formatAmount(goal.currentAmount)} / '
                      '${_formatAmount(goal.targetAmount)} ₸',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: theme.colorScheme.outlineVariant.withValues(
                  alpha: 0.35,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),

            const SizedBox(height: 12),

            if (!completed) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Осталось '
                      '${_formatAmount(remaining)} ₸',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    '≈ ${_formatAmount(monthly)} ₸/мес',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onTopUp,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Пополнить цель'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();

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
          Icon(Icons.flag_outlined, size: 35, color: theme.colorScheme.primary),

          const SizedBox(height: 13),

          Text('Целей пока нет', style: theme.textTheme.titleMedium),

          const SizedBox(height: 5),

          Text(
            'Например, квартира, путешествие или новый ноутбук.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

double? _parseAmount(String value) {
  return double.tryParse(value.replaceAll(',', '.').replaceAll(' ', ''));
}

String _dateText(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
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
