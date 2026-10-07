import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/budget.dart';
import '../../domain/entities/finance_transaction.dart';
import '../controllers/budget_controller.dart';
import '../controllers/finance_controller.dart';
import '../screens/budgets_screen.dart';

class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final budgetController = context.watch<BudgetController>();

    final financeController = context.watch<FinanceController>();

    final activeBudgets =
        budgetController.budgets.where((budget) => budget.enabled).toList();

    if (budgetController.budgets.isEmpty) {
      return _EmptyBudgetCard(
        onTap: () {
          _openBudgets(context);
        },
      );
    }

    if (activeBudgets.isEmpty) {
      return _DisabledBudgetsCard(
        onTap: () {
          _openBudgets(context);
        },
      );
    }

    final progresses =
        activeBudgets
            .map(
              (budget) => _BudgetProgress(
                budget: budget,
                spent: _spentForBudget(budget, financeController),
              ),
            )
            .toList();

    progresses.sort((a, b) => b.progress.compareTo(a.progress));

    final totalLimit = progresses.fold<double>(
      0,
      (sum, item) => sum + item.budget.monthlyLimit,
    );

    final totalSpent = progresses.fold<double>(
      0,
      (sum, item) => sum + item.spent,
    );

    final totalProgress = totalLimit <= 0 ? 0.0 : totalSpent / totalLimit;

    final summaryColor =
        totalProgress >= 1
            ? theme.colorScheme.error
            : totalProgress >= 0.8
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: summaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.pie_chart_outline_rounded,
                  color: summaryColor,
                  size: 20,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Бюджеты', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatAmount(totalSpent)} из '
                      '${_formatAmount(totalLimit)} ₸',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),

              TextButton(
                onPressed: () {
                  _openBudgets(context);
                },
                child: const Text('Все'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: totalProgress.clamp(0.0, 1.0).toDouble(),
              ),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.35,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(summaryColor),
                );
              },
            ),
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              Expanded(
                child: Text(
                  totalProgress >= 1
                      ? 'Общий лимит превышен'
                      : 'Использовано '
                          '${(totalProgress * 100).round()}%',
                  style: TextStyle(
                    color: summaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                totalSpent > totalLimit
                    ? '+${_formatAmount(totalSpent - totalLimit)} ₸'
                    : 'Осталось '
                        '${_formatAmount(totalLimit - totalSpent)} ₸',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
              ),
            ],
          ),

          const SizedBox(height: 18),

          ...progresses.take(3).map((progress) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BudgetRow(progress: progress),
            );
          }),

          if (progresses.length > 3)
            Center(
              child: TextButton.icon(
                onPressed: () {
                  _openBudgets(context);
                },
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: Text('Ещё ${progresses.length - 3}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final _BudgetProgress progress;

  const _BudgetRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final budget = progress.budget;

    final categoryName =
        FinanceController.expenseCategories[budget.categoryId] ?? 'Другое';

    final ratio = progress.progress;

    final color =
        ratio >= 1
            ? theme.colorScheme.error
            : ratio >= 0.8
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(_categoryIcon(budget.categoryId), size: 18, color: color),
        ),

        const SizedBox(width: 10),

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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    '${(ratio * 100).round()}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 5),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0).toDouble(),
                  minHeight: 5,
                  backgroundColor: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.35,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '${_formatAmount(progress.spent)} / '
                '${_formatAmount(budget.monthlyLimit)} ₸',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyBudgetCard extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyBudgetCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.pie_chart_outline_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Создай первый бюджет',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Следи за лимитами расходов',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),

              Icon(Icons.add_rounded, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisabledBudgetsCard extends StatelessWidget {
  final VoidCallback onTap;

  const _DisabledBudgetsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications_off_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Все бюджеты отключены',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetProgress {
  final Budget budget;
  final double spent;

  const _BudgetProgress({required this.budget, required this.spent});

  double get progress {
    if (budget.monthlyLimit <= 0) {
      return 0;
    }

    return spent / budget.monthlyLimit;
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

void _openBudgets(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const BudgetsScreen();
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
