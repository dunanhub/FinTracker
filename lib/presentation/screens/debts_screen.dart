import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/debt.dart';
import '../controllers/debt_controller.dart';
import 'add_debt_screen.dart';
import 'debt_details_screen.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = context.finColors;

    final controller = context.watch<DebtController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Долги')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  title: 'Я должен',
                  amount: controller.totalIOwe,
                  icon: Icons.north_east_rounded,
                  color: colors.expense,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _SummaryItem(
                  title: 'Мне должны',
                  amount: controller.totalOwedToMe,
                  icon: Icons.south_west_rounded,
                  color: colors.income,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: Text('Все долги', style: theme.textTheme.titleLarge),
              ),
              Text(
                '${controller.debts.length}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (controller.debts.isEmpty)
            const _EmptyDebts()
          else
            ...controller.debts.map(
              (debt) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DebtCard(debt: debt),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddDebtScreen()));
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить'),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_formatAmount(amount)} ₸',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final Debt debt;

  const _DebtCard({required this.debt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = context.finColors;

    final color =
        debt.isPaid
            ? theme.colorScheme.onSurfaceVariant
            : debt.type == DebtType.iOwe
            ? colors.expense
            : colors.income;

    final overdue =
        !debt.isPaid &&
        debt.deadline != null &&
        debt.deadline!.isBefore(DateTime.now());

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DebtDetailsScreen(debtId: debt.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      debt.isPaid
                          ? Icons.check_rounded
                          : debt.type == DebtType.iOwe
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
                        Text(
                          debt.person,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          debt.isPaid
                              ? 'Погашено'
                              : debt.type == DebtType.iOwe
                              ? 'Я должен'
                              : 'Мне должны',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_formatAmount(debt.remainingAmount)} ₸',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(width: 3),

                  const Icon(Icons.chevron_right_rounded),
                ],
              ),

              const SizedBox(height: 14),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: debt.progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.35,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),

              if (debt.deadline != null) ...[
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(
                      overdue
                          ? Icons.warning_amber_rounded
                          : Icons.calendar_today_outlined,
                      size: 14,
                      color:
                          overdue
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      overdue
                          ? 'Просрочено · '
                              '${_dateText(debt.deadline!)}'
                          : 'До ${_dateText(debt.deadline!)}',
                      style: TextStyle(
                        color:
                            overdue
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDebts extends StatelessWidget {
  const _EmptyDebts();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Icon(
            Icons.handshake_outlined,
            size: 35,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text('Долгов пока нет', style: theme.textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            'Добавь долг, чтобы контролировать возвраты.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

String _dateText(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String _formatAmount(double value) {
  final rounded = value.round();

  final digits = rounded.abs().toString();

  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;

    buffer.write(digits[i]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }

  return buffer.toString();
}
