import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/finance_transaction.dart';
import '../controllers/budget_controller.dart';
import '../controllers/finance_controller.dart';
import 'add_budget_screen.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final budgets = context.watch<BudgetController>();

    final finance = context.watch<FinanceController>();

    final activeBudgets =
        budgets.budgets.where((budget) => budget.enabled).toList();

    final totalLimit = activeBudgets.fold<double>(
      0,
      (sum, budget) => sum + budget.monthlyLimit,
    );

    final totalSpent = activeBudgets.fold<double>(
      0,
      (sum, budget) => sum + _spentForBudget(budget, finance),
    );

    final remaining = totalLimit - totalSpent;

    return Scaffold(
      appBar: AppBar(title: const Text('Бюджеты')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          _SummaryCard(
            totalLimit: totalLimit,
            spent: totalSpent,
            remaining: remaining,
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: Text('Категории', style: theme.textTheme.titleLarge),
              ),
              Text(
                '${budgets.budgets.length}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (budgets.budgets.isEmpty)
            const _EmptyBudgets()
          else
            ...budgets.budgets.map((budget) {
              final spent = _spentForBudget(budget, finance);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BudgetCard(
                  budget: budget,
                  spent: spent,
                  onTap: () {
                    _openBudget(context, budget);
                  },
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openBudget(context, null);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить'),
      ),
    );
  }

  void _openBudget(BuildContext context, Budget? budget) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) {
          return AddBudgetScreen(budget: budget);
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
}

class _SummaryCard extends StatelessWidget {
  final double totalLimit;
  final double spent;
  final double remaining;

  const _SummaryCard({
    required this.totalLimit,
    required this.spent,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = context.finColors;

    final progress =
        totalLimit <= 0 ? 0.0 : (spent / totalLimit).clamp(0.0, 1.0).toDouble();

    final exceeded = remaining < 0;

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
          Text('Бюджет месяца', style: theme.textTheme.bodyMedium),

          const SizedBox(height: 6),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${_formatAmount(spent)} / '
              '${_formatAmount(totalLimit)} ₸',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26),
            ),
          ),

          const SizedBox(height: 18),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.outlineVariant.withValues(
                alpha: 0.4,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(
                exceeded
                    ? colors.expense
                    : progress >= 0.8
                    ? Colors.orange
                    : theme.colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Icon(
                exceeded
                    ? Icons.warning_amber_rounded
                    : Icons.account_balance_wallet_outlined,
                size: 18,
                color: exceeded ? colors.expense : theme.colorScheme.primary,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  exceeded
                      ? 'Лимит превышен на '
                          '${_formatAmount(remaining.abs())} ₸'
                      : 'Осталось '
                          '${_formatAmount(remaining)} ₸',
                  style: TextStyle(
                    color:
                        exceeded
                            ? colors.expense
                            : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),

              Text(
                '${(progress * 100).round()}%',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final double spent;
  final VoidCallback onTap;

  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = context.finColors;

    final categoryName =
        FinanceController.expenseCategories[budget.categoryId] ?? 'Другое';

    final rawProgress =
        budget.monthlyLimit <= 0 ? 0.0 : spent / budget.monthlyLimit;

    final progress = rawProgress.clamp(0.0, 1.0).toDouble();

    final warning = rawProgress >= 0.8;

    final exceeded = rawProgress >= 1;

    final progressColor =
        exceeded
            ? colors.expense
            : warning
            ? Colors.orange
            : theme.colorScheme.primary;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
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
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _categoryIcon(budget.categoryId),
                      color: progressColor,
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                categoryName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),

                            if (!budget.enabled)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Выкл.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        Text(
                          '${_formatAmount(spent)} из '
                          '${_formatAmount(budget.monthlyLimit)} ₸',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 13),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.35,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    budget.enabled
                        ? progressColor
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(height: 9),

              Row(
                children: [
                  if (exceeded)
                    Text(
                      'Лимит превышен',
                      style: TextStyle(
                        color: colors.expense,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (warning)
                    const Text(
                      'Почти достигнут лимит',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      'Осталось '
                      '${_formatAmount(budget.monthlyLimit - spent)} ₸',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
                    ),

                  const Spacer(),

                  Text(
                    '${(rawProgress * 100).round()}%',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets();

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
            Icons.pie_chart_outline_rounded,
            color: theme.colorScheme.primary,
            size: 34,
          ),
          const SizedBox(height: 13),
          Text('Бюджетов пока нет', style: theme.textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            'Например, поставь лимит 100 000 ₸ на еду.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

double _spentForBudget(Budget budget, FinanceController finance) {
  final now = DateTime.now();

  return finance.transactions
      .where(
        (transaction) =>
            transaction.type == FinanceTransactionType.expense &&
            transaction.categoryId == budget.categoryId &&
            transaction.date.year == now.year &&
            transaction.date.month == now.month,
      )
      .fold<double>(0, (sum, transaction) => sum + transaction.amount);
}

IconData _categoryIcon(String id) {
  switch (id) {
    case 'food':
      return Icons.restaurant_rounded;
    case 'housing':
      return Icons.home_outlined;
    case 'transport':
      return Icons.directions_car_outlined;
    case 'subscriptions':
      return Icons.subscriptions_outlined;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'health':
      return Icons.favorite_border_rounded;
    case 'entertainment':
      return Icons.movie_outlined;
    default:
      return Icons.category_outlined;
  }
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
