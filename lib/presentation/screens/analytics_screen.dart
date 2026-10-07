import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../controllers/finance_controller.dart';
import '../widgets/smooth_line_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finColors = context.finColors;

    final finance = context.watch<FinanceController>();

    final analytics = finance.analyticsSnapshot(_period);

    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 20,
          18,
          compact ? 16 : 20,
          150,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AnimatedEntry(
              delay: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Аналитика', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 5),
                  Text(
                    'Следи за динамикой своих финансов',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _AnimatedEntry(
              delay: 70,
              child: _PeriodSelector(
                value: _period,
                onChanged: (period) {
                  setState(() {
                    _period = period;
                  });
                },
              ),
            ),

            const SizedBox(height: 18),

            _AnimatedEntry(
              delay: 120,
              child: _MainChartCard(analytics: analytics),
            ),

            const SizedBox(height: 18),

            _AnimatedEntry(
              delay: 170,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 12) / 2;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'Доходы',
                          amount: '${_formatAmount(analytics.income)} ₸',
                          icon: Icons.south_west_rounded,
                          color: finColors.income,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'Расходы',
                          amount: '${_formatAmount(analytics.expense)} ₸',
                          icon: Icons.north_east_rounded,
                          color: finColors.expense,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'Сбережения',
                          amount: _signedAmount(analytics.savings),
                          icon:
                              analytics.savings >= 0
                                  ? Icons.savings_outlined
                                  : Icons.trending_down_rounded,
                          color:
                              analytics.savings >= 0
                                  ? finColors.transfer
                                  : finColors.expense,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'Savings rate',
                          amount: '${(analytics.savingsRate * 100).round()}%',
                          icon: Icons.trending_up_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            _AnimatedEntry(
              delay: 220,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'По категориям',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (analytics.categories.isNotEmpty)
                    Text(
                      '${analytics.categories.length} катег.',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _AnimatedEntry(
              delay: 270,
              child:
                  analytics.categories.isEmpty
                      ? const _EmptyCategories()
                      : _CategoriesList(analytics: analytics),
            ),

            if (analytics.categories.isNotEmpty) ...[
              const SizedBox(height: 24),

              _AnimatedEntry(
                delay: 320,
                child: _InsightCard(analytics: analytics),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final AnalyticsPeriod value;

  final ValueChanged<AnalyticsPeriod> onChanged;

  const _PeriodSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _PeriodButton(
            title: 'Неделя',
            value: AnalyticsPeriod.week,
            selected: value == AnalyticsPeriod.week,
            onChanged: onChanged,
          ),
          _PeriodButton(
            title: 'Месяц',
            value: AnalyticsPeriod.month,
            selected: value == AnalyticsPeriod.month,
            onChanged: onChanged,
          ),
          _PeriodButton(
            title: 'Год',
            value: AnalyticsPeriod.year,
            selected: value == AnalyticsPeriod.year,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String title;

  final AnalyticsPeriod value;

  final bool selected;

  final ValueChanged<AnalyticsPeriod> onChanged;

  const _PeriodButton({
    required this.title,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        onTap: () {
          onChanged(value);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                color:
                    selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainChartCard extends StatelessWidget {
  final AnalyticsSnapshot analytics;

  const _MainChartCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finColors = context.finColors;

    final change = analytics.expenseChangePercent;

    final expensesLower = change < 0;

    final comparisonColor =
        expensesLower ? finColors.income : finColors.expense;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Расходы за период', style: theme.textTheme.bodyMedium),

          const SizedBox(height: 6),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              '${_formatAmount(analytics.expense)} ₸',
              key: ValueKey('${analytics.period}-${analytics.expense}'),
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 27),
            ),
          ),

          const SizedBox(height: 6),

          if (analytics.hasPreviousData)
            Row(
              children: [
                Icon(
                  expensesLower ? Icons.south_rounded : Icons.north_rounded,
                  color: comparisonColor,
                  size: 15,
                ),

                const SizedBox(width: 4),

                Expanded(
                  child: Text(
                    '${change > 0 ? '+' : ''}'
                    '${change.toStringAsFixed(1)}% '
                    'к прошлому периоду',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: comparisonColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              'Недостаточно данных для сравнения',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),

          const SizedBox(height: 24),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: SmoothLineChart(
              key: ValueKey(
                '${analytics.period.name}-'
                '${analytics.chartValues.join('-')}',
              ),
              values: analytics.chartValues,
              dates: analytics.chartDates,
              showMonthOnly: analytics.period == AnalyticsPeriod.year,
              lineColor: theme.colorScheme.primary,
              height: 155,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children:
                analytics.chartLabels.map((label) {
                  return Expanded(
                    child: Text(
                      label,
                      textAlign:
                          analytics.chartLabels.first == label
                              ? TextAlign.left
                              : analytics.chartLabels.last == label
                              ? TextAlign.right
                              : TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String amount;

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
      height: 128,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),

          const Spacer(),

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
          ),

          const SizedBox(height: 4),

          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                maxLines: 1,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesList extends StatelessWidget {
  final AnalyticsSnapshot analytics;

  const _CategoriesList({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finColors = context.finColors;

    final colors = [
      theme.colorScheme.primary,
      finColors.expense,
      finColors.transfer,
      finColors.income,
      theme.colorScheme.secondary,
    ];

    final categories = analytics.categories.take(5).toList();

    return Column(
      children: [
        for (var index = 0; index < categories.length; index++) ...[
          _CategoryCard(
            category: categories[index],
            totalExpense: analytics.expense,
            color: colors[index % colors.length],
          ),

          if (index != categories.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final FinanceCategoryTotal category;

  final double totalExpense;

  final Color color;

  const _CategoryCard({
    required this.category,
    required this.totalExpense,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final progress =
        totalExpense <= 0
            ? 0.0
            : (category.amount / totalExpense).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_categoryIcon(category.id), size: 19, color: color),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '${(progress * 100).round()}% расходов',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_formatAmount(category.amount)} ₸',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.35,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final AnalyticsSnapshot analytics;

  const _InsightCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final biggest = analytics.categories.first;

    final percentage =
        analytics.expense <= 0
            ? 0
            : ((biggest.amount / analytics.expense) * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: theme.colorScheme.primary,
              size: 21,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Финансовый инсайт',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 13),
                ),

                const SizedBox(height: 4),

                Text(
                  'Больше всего ушло на «${biggest.name}» — '
                  '$percentage% всех расходов.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    height: 1.4,
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

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pie_chart_outline_rounded,
              color: theme.colorScheme.primary,
              size: 25,
            ),
          ),

          const SizedBox(height: 13),

          Text(
            'Нет расходов за этот период',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 13),
          ),

          const SizedBox(height: 5),

          Text(
            'Добавь операции, и здесь появится аналитика.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _AnimatedEntry extends StatelessWidget {
  final int delay;

  final Widget child;

  const _AnimatedEntry({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
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

String _signedAmount(double value) {
  if (value > 0) {
    return '+${_formatAmount(value)} ₸';
  }

  if (value < 0) {
    return '−${_formatAmount(value.abs())} ₸';
  }

  return '0 ₸';
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

  return '${negative ? '-' : ''}${buffer.toString()}';
}
